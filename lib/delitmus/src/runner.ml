(* The Automagic Compiler Tormentor

   Copyright (c) 2018--2019 Matt Windsor and contributors

   ACT itself is licensed under the MIT License. See the LICENSE file in the
   project root for more information.

   ACT is based in part on code from the Herdtools7 project
   (https://github.com/herd/herdtools7) : see the LICENSE.herd file in the
   project root for more information. *)

open Base
module Ac = Act_common
module C = Act_c
module Tx = Travesty_base_exts

let make_initialiser ((ty, value) : C.Mini.Type.t * C.Mini.Constant.t) =
  (* NB: Apparently, we don't need ATOMIC_VAR_INIT here: every known C11
     compiler can make do without it, and as a result it's obsolete as of
     C17. *)
  C.Mini.Initialiser.make ~ty ~value ()

let parameter_list_equal :
       C.Mini.Type.t C.Mini_intf.id_assoc
    -> C.Mini.Type.t C.Mini_intf.id_assoc
    -> bool =
  [%equal: (Ac.C_id.t * C.Mini.Type.t) list]

let check_parameters_consistent
    (params : C.Mini.Type.t C.Mini_intf.id_assoc) (next : C.Mini.Function.t)
    : unit Or_error.t =
  let params' = C.Mini.Function.parameters next in
  if parameter_list_equal params params' then Result.ok_unit
  else
    Or_error.error_s
      [%message
        "Functions do not agree on parameter lists"
          ~first_example:(params : C.Mini.Type.t C.Mini_intf.id_assoc)
          ~second_example:(params' : C.Mini.Type.t C.Mini_intf.id_assoc)]

let functions_to_parameter_map :
    C.Mini.Function.t list -> C.Mini.Type.t C.Mini_intf.id_assoc Or_error.t
    = function
  | [] ->
      Or_error.error_string "need at least one function"
  | x :: xs ->
      let open Or_error.Let_syntax in
      let params = C.Mini.Function.parameters x in
      let%map () =
        xs
        |> List.map ~f:(check_parameters_consistent params)
        |> Or_error.combine_errors_unit
      in
      params

let merge_init_and_params (init : C.Mini.Constant.t C.Mini_intf.id_assoc)
    (params : C.Mini.Type.t C.Mini_intf.id_assoc) :
    (C.Mini.Type.t * C.Mini.Constant.t) C.Mini_intf.id_assoc Or_error.t =
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
let dereference_params (params : C.Mini.Type.t C.Mini_intf.id_assoc) :
    C.Mini.Type.t C.Mini_intf.id_assoc Or_error.t =
  Or_error.(
    params
    |> List.map ~f:(fun (id, ty) ->
           ty |> C.Mini.Type.deref >>| fun ty' -> (id, ty') )
    |> combine_errors)

(** [make_init_globals init functions] converts a Litmus initialiser list to
    a set of global variable declarations, using the type information from
    [functions].

    It fails if the functions list is empty, is inconsistent with its
    parameters, or the parameters don't match the initialiser. *)
let make_init_globals (init : C.Mini.Constant.t C.Mini_intf.id_assoc)
    (functions : C.Mini.Function.t list) :
    (C.Mini.Identifier.t, C.Mini.Initialiser.t) List.Assoc.t Or_error.t =
  Or_error.(
    functions |> functions_to_parameter_map >>= dereference_params
    >>= merge_init_and_params init
    >>| List.Assoc.map ~f:make_initialiser)

let make_single_func_globals (tid : int) (func : C.Mini.Function.t) :
    C.Mini.Initialiser.t C.Mini_intf.id_assoc =
  Tx.Alist.map_left ~f:(Qualify.local tid) (C.Mini.Function.body_decls func)

let make_func_globals (funcs : C.Mini.Function.t list) :
    C.Mini.Initialiser.t C.Mini_intf.id_assoc =
  funcs |> List.mapi ~f:make_single_func_globals |> List.concat

module Global_reduce (T : Thread.S) = struct
  (** [address_globals stm] converts each address in [stm] over a global
      variable [v] to [&*v], ready for {{!ref_globals} ref_globals} to
      reduce to [&v]. *)
  let address_globals : C.Mini.Statement.t -> C.Mini.Statement.t =
    C.Mini.Statement.On_addresses.map
      ~f:
        (T.when_global ~over:C.Mini.Address.variable_of ~f:(fun addr ->
             (* The added deref here will be removed in [ref_globals]. *)
             C.Mini.Address.ref
               (C.Mini.Address.On_lvalues.map ~f:C.Mini.Lvalue.deref addr)
         ))

  (** [ref_globals stm] turns all dereferences of global variables in [stm]
      into direct accesses to the same variables. *)
  let ref_globals : C.Mini.Statement.t -> C.Mini.Statement.t =
    C.Mini.Statement.On_lvalues.map
      ~f:
        C.Mini.Lvalue.(
          T.when_global ~over:variable_of
            ~f:(Fn.compose variable variable_of))

  (** [proc_stm stm] runs all of the global-handling functions on a single
      statement. *)
  let proc_stm (stm : C.Mini.Statement.t) : C.Mini.Statement.t =
    stm |> address_globals |> ref_globals
    |> Qualify.locals_in_statement (module T)

  (** [proc_stms stms] runs all of the global-handling functions on multiple
      statements. *)
  let proc_stms : C.Mini.Statement.t list -> C.Mini.Statement.t list =
    List.map ~f:proc_stm
end

let global_reduce (tid : int) (locals : C.Mini.Identifier.Set.t) :
    C.Mini.Statement.t list -> C.Mini.Statement.t list =
  let module T = Thread.Make (struct
    let tid = tid

    let locals = locals
  end) in
  let module M = Global_reduce (T) in
  M.proc_stms

let delitmus_stms (tid : int)
    (locals : C.Mini.Initialiser.t C.Mini_intf.id_assoc) :
    C.Mini.Statement.t list -> C.Mini.Statement.t list =
  let locals_set =
    locals |> List.map ~f:fst |> C.Mini.Identifier.Set.of_list
  in
  global_reduce tid locals_set

let delitmus_function (tid : int) (func : C.Mini.Function.t) :
    C.Mini.Function.t =
  let locals = C.Mini.Function.body_decls func in
  C.Mini.Function.map func ~parameters:(Fn.const [])
    ~body_decls:(Fn.const [])
    ~body_stms:(delitmus_stms tid locals)

let delitmus_functions :
       C.Mini.Function.t C.Mini_intf.id_assoc
    -> C.Mini.Function.t C.Mini_intf.id_assoc =
  List.mapi ~f:(fun tid (name, f) -> (name, delitmus_function tid f))

let make_globals (init : C.Mini.Constant.t C.Mini_intf.id_assoc)
    (function_bodies : C.Mini.Function.t list) :
    C.Mini_initialiser.t C.Mini_intf.id_assoc Or_error.t =
  let func_globals = make_func_globals function_bodies in
  Or_error.Let_syntax.(
    let%map init_globals = make_init_globals init function_bodies in
    init_globals @ func_globals)

let qualify_if_local (var : Ac.C_id.t) (record : Ac.C_variables.Record.t) :
    Ac.C_id.t * Ac.C_variables.Record.t =
  match Ac.C_variables.Record.tid record with
  | None ->
      (var, record)
  | Some tid ->
      (Qualify.local tid var, Ac.C_variables.Record.remove_tid record)

let cvars_with_qualified_locals (cvars : Ac.C_variables.Map.t) :
    Ac.C_variables.Map.t Or_error.t =
  Ac.C_variables.Map.map cvars ~f:qualify_if_local

let make_litmus_aux (input : C.Mini_litmus.Ast.Validated.t) :
    C.Mini.Constant.t Act_litmus.Aux.t =
  let postcondition =
    Option.map
      (C.Mini_litmus.Ast.Validated.postcondition input)
      ~f:Qualify.postcondition
  in
  (* These _should_ be ok to pass through verbatim; they only use global
     variables. *)
  let init = C.Mini_litmus.Ast.Validated.init input in
  let locations = C.Mini_litmus.Ast.Validated.locations input in
  Act_litmus.Aux.make ?postcondition ~init ?locations ()

let run (input : C.Mini_litmus.Ast.Validated.t) : Output.t Or_error.t =
  (* TODO(@MattWindsor91): the variable logic here is completely wrong! It
     needs to maintain the full Litmus identifiers at all times, then build
     a mapping. *)
  let init = C.Mini_litmus.Ast.Validated.init input in
  let raw_functions = C.Mini_litmus.Ast.Validated.programs input in
  let function_bodies = List.map ~f:snd raw_functions in
  let functions = delitmus_functions raw_functions in
  let raw_c_variables = C.Mini_litmus.cvars input in
  Or_error.Let_syntax.(
    let%bind globals = make_globals init function_bodies in
    let program = C.Mini.Program.make ~globals ~functions in
    let%map c_variables = cvars_with_qualified_locals raw_c_variables in
    let litmus_aux = make_litmus_aux input in
    let aux = Output.Aux.make ~litmus_aux ~c_variables in
    Output.make ~program ~aux)