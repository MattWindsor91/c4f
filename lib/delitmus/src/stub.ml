(* The Automagic Compiler Tormentor

   Copyright (c) 2018, 2019, 2020 Matt Windsor and contributors

   ACT itself is licensed under the MIT License. See the LICENSE file in the
   project root for more information.

   ACT is based in part on code from the Herdtools7 project
   (https://github.com/herd/herdtools7) : see the LICENSE.herd file in the
   project root for more information. *)

open Base

open struct
  module A = Accessor_base
  module Ac = Act_common
  module Tx = Travesty_base_exts
end

let try_parse_program_id (id : Ac.C_id.t) : int Or_error.t =
  let strid = Ac.C_id.to_string id in
  Or_error.(
    tag ~tag:"Thread function does not have a well-formed name"
      (try_with (fun () -> Caml.Scanf.sscanf strid "P%d" Fn.id)))

let to_param_opt (lit_id : Ac.Litmus_id.t) (rc : Var_map.Record.t) :
    (int * (Ac.Litmus_id.t * Act_fir.Type.t)) option =
  match Var_map.Record.mapped_to rc with
  | Param k ->
      Some (k, (lit_id, Var_map.Record.c_type rc))
  | Global ->
      None

let to_sorted_params_opt
    (alist : (Ac.Litmus_id.t, Var_map.Record.t) List.Assoc.t) :
    (Ac.Litmus_id.t, Act_fir.Type.t) List.Assoc.t =
  alist
  |> List.filter_map ~f:(fun (l, r) -> to_param_opt l r)
  |> List.sort ~compare:(Comparable.lift Int.compare ~f:fst)
  |> List.map ~f:snd

let sorted_params (vars : Var_map.t) :
    (Ac.Litmus_id.t, Act_fir.Type.t) List.Assoc.t =
  vars |> Ac.Scoped_map.to_litmus_id_map |> Map.to_alist
  |> to_sorted_params_opt

(** Adjusts the type of a parameter in a (ID, type) associative list by
    turning it into a pointer if it is global, and leaving it unchanged
    otherwise.

    This serves to make the type fit its position in the stub: pointers to
    the Litmus harness's variables if global, local variables otherwise. *)
let type_adjusted_param ((id, ty) : Ac.Litmus_id.t * Act_fir.Type.t) :
    (Ac.Litmus_id.t * Act_fir.Type.t) Or_error.t =
  Or_error.Let_syntax.(
    let%map ty' =
      if Ac.Litmus_id.is_global id then Act_fir.Type.ref ty else Ok ty
    in
    (id, ty'))

(** Produces a list of sorted, type-adjusted parameters from [vars]. These
    are the parameters of the inner call, and need to be filtered to produce
    the other parameter/argument lists. *)
let sorted_type_adjusted_params (vars : Var_map.t) :
    (Ac.Litmus_id.t, Act_fir.Type.t) List.Assoc.t Or_error.t =
  vars |> sorted_params |> Tx.Or_error.combine_map ~f:type_adjusted_param

let thread_params :
       (Ac.Litmus_id.t, Act_fir.Type.t) List.Assoc.t
    -> (Ac.C_id.t, Act_fir.Type.t) List.Assoc.t =
  List.filter_map ~f:(fun (id, ty) ->
      Option.map ~f:(fun id' -> (id', ty)) (Ac.Litmus_id.as_global id))

let local_decls (tid : int) :
       (Ac.Litmus_id.t, Act_fir.Type.t) List.Assoc.t
    -> (Ac.C_id.t, Act_fir.Initialiser.t) List.Assoc.t =
  List.filter_map ~f:(fun (id, ty) ->
      if [%equal: int option] (Ac.Litmus_id.tid id) (Some tid) then
        Some
          ( Ac.Litmus_id.variable_name id
          , Act_fir.Initialiser.make
              ~ty (* TODO(@MattWindsor91): fix this properly. *)
              ~value:(Act_fir.Constant.int 0) )
      else None)

let inner_call_argument (lid : Ac.Litmus_id.t) (ty : Act_fir.Type.t) :
    Act_fir.Expression.t =
  let id = Ac.Litmus_id.variable_name lid in
  let tid = Ac.C_named.make ~name:id ty in
  Act_fir.Expression.address (Act_fir.Address.on_address_of_typed_id tid)

let inner_call_arguments (tid : int) :
       (Ac.Litmus_id.t, Act_fir.Type.t) List.Assoc.t
    -> Act_fir.Expression.t list =
  List.filter_map ~f:(fun (lid, ty) ->
      if Ac.Litmus_id.is_in_local_scope ~from:tid lid then
        Some (inner_call_argument lid ty)
      else None)

let inner_call_stm (tid : int) (function_id : Ac.C_id.t)
    (all_params : (Ac.Litmus_id.t, Act_fir.Type.t) List.Assoc.t) :
    unit Act_fir.Statement.t =
  let arguments = inner_call_arguments tid all_params in
  let call = Act_fir.Call.make ~function_id ~arguments () in
  A.(
    construct Act_fir.(Statement.prim' @> Prim_statement.procedure_call) call)

let make_function_stub (vars : Var_map.t) ~(old_id : Ac.C_id.t)
    ~(new_id : Ac.C_id.t) : unit Act_fir.Function.t Ac.C_named.t Or_error.t =
  (* TODO(@MattWindsor91): eventually, we'll have variables that don't
     propagate outside of the wrapper into Litmus; in that case, the function
     stub should pass in their initial values directly. *)
  Or_error.Let_syntax.(
    let%bind all_params = sorted_type_adjusted_params vars in
    let parameters = thread_params all_params in
    let%map tid = try_parse_program_id old_id in
    let body_decls = local_decls tid all_params in
    let body_stms = [inner_call_stm tid new_id all_params] in
    let thread =
      Act_fir.Function.make ~parameters ~body_decls ~body_stms ()
    in
    Ac.C_named.make thread ~name:old_id)

let make (aux : Aux.t) : Act_fir.Litmus.Test.t Or_error.t =
  let header = Aux.litmus_header aux in
  let vars = Aux.var_map aux in
  Or_error.Let_syntax.(
    let%bind threads =
      aux |> Aux.function_map
      |> Map.to_alist ~key_order:`Increasing
      |> List.filter_map ~f:(fun (old_id, record) ->
             if Function_map.Record.is_thread_body record then
               Some
                 (make_function_stub vars ~old_id
                    ~new_id:(Function_map.Record.c_id record))
             else None)
      |> Or_error.combine_errors
    in
    Act_fir.Litmus.Test.make ~header ~threads)

module Filter = struct
  let run (input : Plumbing.Input.t) (output : Plumbing.Output.t) :
      unit Or_error.t =
    Or_error.(
      input |> Aux.load >>= make
      >>= Act_utils.My_format.odump output
            (Fmt.vbox Act_litmus_c.Reify.pp_litmus))
end
