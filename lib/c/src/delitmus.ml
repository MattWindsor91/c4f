(* This file is part of 'act'.

   Copyright (c) 2018, 2019 by Matt Windsor

   Permission is hereby granted, free of charge, to any person obtaining a
   copy of this software and associated documentation files (the
   "Software"), to deal in the Software without restriction, including
   without limitation the rights to use, copy, modify, merge, publish,
   distribute, sublicense, and/or sell copies of the Software, and to permit
   persons to whom the Software is furnished to do so, subject to the
   following conditions:

   The above copyright notice and this permission notice shall be included
   in all copies or substantial portions of the Software.

   THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS
   OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
   MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN
   NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM,
   DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR
   OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE
   USE OR OTHER DEALINGS IN THE SOFTWARE. *)

open Core_kernel
module Ac = Act_common

let make_initialiser ((ty, value) : Mini.Type.t * Mini.Constant.t) =
  (* NB: Apparently, we don't need ATOMIC_VAR_INIT here: every known C11
     compiler can make do without it, and as a result it's obsolete as of
     C17. *)
  Mini.Initialiser.make ~ty ~value ()

let parameter_list_equal :
    Mini.Type.t Mini_intf.id_assoc -> Mini.Type.t Mini_intf.id_assoc -> bool
    =
  [%equal: (Ac.C_id.t * Mini.Type.t) list]

let check_parameters_consistent (params : Mini.Type.t Mini_intf.id_assoc)
    (next : Mini.Function.t) : unit Or_error.t =
  let params' = Mini.Function.parameters next in
  if parameter_list_equal params params' then Result.ok_unit
  else
    Or_error.error_s
      [%message
        "Functions do not agree on parameter lists"
          ~first_example:(params : Mini.Type.t Mini_intf.id_assoc)
          ~second_example:(params' : Mini.Type.t Mini_intf.id_assoc)]

let functions_to_parameter_map :
    Mini.Function.t list -> Mini.Type.t Mini_intf.id_assoc Or_error.t =
  function
  | [] ->
      Or_error.error_string "need at least one function"
  | x :: xs ->
      let open Or_error.Let_syntax in
      let params = Mini.Function.parameters x in
      let%map () =
        xs
        |> List.map ~f:(check_parameters_consistent params)
        |> Or_error.combine_errors_unit
      in
      params

let merge_init_and_params (init : Mini.Constant.t Mini_intf.id_assoc)
    (params : Mini.Type.t Mini_intf.id_assoc) :
    (Mini.Type.t * Mini.Constant.t) Mini_intf.id_assoc Or_error.t =
  let i_ids = init |> List.map ~f:fst |> Ac.C_id.Set.of_list in
  let p_ids = params |> List.map ~f:fst |> Ac.C_id.Set.of_list in
  if Ac.C_id.Set.equal i_ids p_ids then
    params
    |> List.map ~f:(fun (id, ty) ->
           (id, (ty, List.Assoc.find_exn ~equal:Ac.C_id.equal init id)) )
    |> Or_error.return
  else
    Or_error.error_s
      [%message
        "Init and parameters lists don't agree"
          ~init_ids:(i_ids : Ac.C_id.Set.t)
          ~param_ids:(p_ids : Ac.C_id.Set.t)]

(** [dereference_params params] tries to convert each parameter in [params]
    from a pointer type to a non-pointer type. It fails if any of the
    parameters are non-pointer types.

    Since we assume that litmus tests contain pointers to the global
    variables in their parameter lists, failure of this function generally
    means the litmus test being delitmusified is ill-formed. *)
let dereference_params (params : Mini.Type.t Mini_intf.id_assoc) :
    Mini.Type.t Mini_intf.id_assoc Or_error.t =
  Or_error.(
    params
    |> List.map ~f:(fun (id, ty) ->
           ty |> Mini.Type.deref >>| Tuple2.create id )
    |> combine_errors)

(** [make_init_globals init functions] converts a Litmus initialiser list to
    a set of global variable declarations, using the type information from
    [functions].

    It fails if the functions list is empty, is inconsistent with its
    parameters, or the parameters don't match the initialiser. *)
let make_init_globals (init : Mini.Constant.t Mini_intf.id_assoc)
    (functions : Mini.Function.t list) :
    (Mini.Identifier.t, Mini.Initialiser.t) List.Assoc.t Or_error.t =
  Or_error.(
    functions |> functions_to_parameter_map >>= dereference_params
    >>= merge_init_and_params init
    >>| List.Assoc.map ~f:make_initialiser)

let qualify_local (t : int) (id : Mini.Identifier.t) : Mini.Identifier.t =
  Ac.Litmus_id.(to_memalloy_id (local t id))

let%expect_test "qualify_local: example" =
  Fmt.pr "%a@." Ac.C_id.pp (qualify_local 0 (Ac.C_id.of_string "r0")) ;
  [%expect {| t0r0 |}]

let make_single_func_globals (tid : int) (func : Mini.Function.t) :
    Mini.Initialiser.t Mini_intf.id_assoc =
  List.map
    ~f:(fun (k, v) -> (qualify_local tid k, v))
    (Mini.Function.body_decls func)

let make_func_globals (funcs : Mini.Function.t list) :
    Mini.Initialiser.t Mini_intf.id_assoc =
  funcs |> List.mapi ~f:make_single_func_globals |> List.concat

module Global_reduce (L : sig
  val tid : int

  val locals : Mini.Identifier.Set.t
end) =
struct
  let is_local : Mini.Identifier.t -> bool =
    Mini.Identifier.Set.mem L.locals

  let when_local (v : 'a) ~(over : 'a -> Mini.Identifier.t) ~(f : 'a -> 'a)
      : 'a =
    if is_local (over v) then f v else v

  let when_global (v : 'a) ~(over : 'a -> Mini.Identifier.t) ~(f : 'a -> 'a)
      : 'a =
    if is_local (over v) then v else f v

  let qualify_locals : Mini.Statement.t -> Mini.Statement.t =
    Mini.Statement.On_identifiers.map
      ~f:(when_local ~over:Fn.id ~f:(qualify_local L.tid))

  (** [address_globals stm] converts each address in [stm] over a global
      variable [v] to [&*v], ready for {{!ref_globals} ref_globals} to
      reduce to [&v]. *)
  let address_globals : Mini.Statement.t -> Mini.Statement.t =
    Mini.Statement.On_addresses.map
      ~f:
        (when_global ~over:Mini.Address.variable_of ~f:(fun addr ->
             (* The added deref here will be removed in [ref_globals]. *)
             Mini.Address.ref
               (Mini.Address.On_lvalues.map ~f:Mini.Lvalue.deref addr) ))

  (** [ref_globals stm] turns all dereferences of global variables in [stm]
      into direct accesses to the same variables. *)
  let ref_globals : Mini.Statement.t -> Mini.Statement.t =
    Mini.Statement.On_lvalues.map
      ~f:
        Mini.Lvalue.(
          when_global ~over:variable_of ~f:(Fn.compose variable variable_of))

  (** [proc_stm stm] runs all of the global-handling functions on a single
      statement. *)
  let proc_stm (stm : Mini.Statement.t) : Mini.Statement.t =
    stm |> address_globals |> ref_globals |> qualify_locals

  (** [proc_stms stms] runs all of the global-handling functions on multiple
      statements. *)
  let proc_stms : Mini.Statement.t list -> Mini.Statement.t list =
    List.map ~f:proc_stm
end

let global_reduce (tid : int) (locals : Mini.Identifier.Set.t) :
    Mini.Statement.t list -> Mini.Statement.t list =
  let module M = Global_reduce (struct
    let tid = tid

    let locals = locals
  end) in
  M.proc_stms

let delitmus_stms (tid : int)
    (locals : Mini.Initialiser.t Mini_intf.id_assoc) :
    Mini.Statement.t list -> Mini.Statement.t list =
  let locals_set =
    locals |> List.map ~f:fst |> Mini.Identifier.Set.of_list
  in
  global_reduce tid locals_set

let delitmus_function (tid : int) (func : Mini.Function.t) : Mini.Function.t
    =
  let locals = Mini.Function.body_decls func in
  Mini.Function.map func ~parameters:(Fn.const []) ~body_decls:(Fn.const [])
    ~body_stms:(delitmus_stms tid locals)

let delitmus_functions :
    Mini.Function.t Mini_intf.id_assoc -> Mini.Function.t Mini_intf.id_assoc
    =
  List.mapi ~f:(fun tid (name, f) -> (name, delitmus_function tid f))

module Output = struct
  type t = {program: Mini.Program.t; c_variables: Ac.C_variables.Map.t}
  [@@deriving make, fields]
end

let make_globals (init : Mini.Constant.t Mini_intf.id_assoc)
    (function_bodies : Mini.Function.t list) :
    Mini_initialiser.t Mini_intf.id_assoc Or_error.t =
  let open Or_error.Let_syntax in
  let%map init_globals = make_init_globals init function_bodies in
  let func_globals = make_func_globals function_bodies in
  init_globals @ func_globals

let qualify_if_local (var : Ac.C_id.t) (record : Ac.C_variables.Record.t) :
    Ac.C_id.t * Ac.C_variables.Record.t =
  match Ac.C_variables.Record.tid record with
  | None ->
      (var, record)
  | Some tid ->
      (qualify_local tid var, Ac.C_variables.Record.remove_tid record)

let cvars_with_qualified_locals (cvars : Ac.C_variables.Map.t) :
    Ac.C_variables.Map.t Or_error.t =
  Ac.C_variables.Map.map cvars ~f:qualify_if_local

let run (input : Mini_litmus.Ast.Validated.t) : Output.t Or_error.t =
  let open Or_error.Let_syntax in
  let init = Mini_litmus.Ast.Validated.init input in
  let raw_functions = Mini_litmus.Ast.Validated.programs input in
  let function_bodies = List.map ~f:snd raw_functions in
  let%bind globals = make_globals init function_bodies in
  let functions = delitmus_functions raw_functions in
  let program = Mini.Program.make ~globals ~functions in
  let raw_c_variables = Mini_litmus.cvars input in
  let%map c_variables = cvars_with_qualified_locals raw_c_variables in
  Output.make ~program ~c_variables