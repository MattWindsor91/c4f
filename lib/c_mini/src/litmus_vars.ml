(* The Automagic Compiler Tormentor

   Copyright (c) 2018--2019 Matt Windsor and contributors

   ACT itself is licensed under the MIT License. See the LICENSE file in the
   project root for more information.

   ACT is based in part on code from the Herdtools7 project
   (https://github.com/herd/herdtools7) : see the LICENSE.herd file in the
   project root for more information. *)

open Base
module Ac = Act_common
module Tx = Travesty_base_exts

let parameter_list_equal :
       (Ac.C_id.t, Type.t) List.Assoc.t
    -> (Ac.C_id.t, Type.t) List.Assoc.t
    -> bool =
  [%equal: (Ac.C_id.t * Type.t) list]

let check_parameters_consistent (params : Type.t Named.Alist.t)
    (next : Function.t) : unit Or_error.t =
  let params' = Function.parameters next in
  if parameter_list_equal params params' then Result.ok_unit
  else
    Or_error.error_s
      [%message
        "Functions do not agree on parameter lists"
          ~first_example:(params : Type.t Named.Alist.t)
          ~second_example:(params' : Type.t Named.Alist.t)]

let lift_global_var (type a) (c_id : Ac.C_id.t) (ptr_type : Type.t)
    ~(f : Ac.C_id.t -> Type.t -> a Or_error.t) :
    (Ac.Litmus_id.t * a) Or_error.t =
  (* In a memalloy style litmus test, the globals start as fully typed
     pointer parameters, so we scrape the global type context from there. We
     leave the decision of whether to reduce the pointer types back to value
     types up to [f]: in delitmus, we'll want to reduce; in fuzz, we won't. *)
  let lit_id = Act_common.Litmus_id.global c_id in
  Or_error.tag_arg
    Or_error.Let_syntax.(
      let%map result = f c_id ptr_type in
      (lit_id, result))
    "While lifting global out of parameter list" (c_id, ptr_type)
    [%sexp_of: Ac.C_id.t * Type.t]

let lift_global_var_alist (type a) (xs : (Ac.C_id.t, Type.t) List.Assoc.t)
    ~(f : Ac.C_id.t -> Type.t -> a Or_error.t) :
    (Ac.Litmus_id.t, a) List.Assoc.t Or_error.t =
  Tx.Or_error.combine_map xs ~f:(fun (c_id, ptr_type) ->
      lift_global_var ~f c_id ptr_type)

let make_global_var_alist (type a) (progs : Litmus.Test.Lang.Program.t list)
    ~(f : Ac.C_id.t -> Type.t -> a Or_error.t) :
    (Ac.Litmus_id.t, a) List.Assoc.t Or_error.t =
  match progs with
  | [] ->
      Or_error.error_string "need at least one function"
  | x :: xs ->
      let params = Function.parameters (Named.value x) in
      Or_error.(
        xs
        |> List.map
             ~f:
               (Fn.compose (check_parameters_consistent params) Named.value)
        |> Or_error.combine_errors_unit
        >>= fun () -> lift_global_var_alist ~f params)

let lift_local_var (type a) (tid : int) (local_c_id : Act_common.C_id.t)
    (init : Initialiser.t)
    ~(f : int -> Act_common.C_id.t -> Type.t -> a Or_error.t) :
    (Act_common.Litmus_id.t * a) Or_error.t =
  let lit_id = Act_common.Litmus_id.local tid local_c_id in
  let c_type = Initialiser.ty init in
  Or_error.Let_syntax.(
    let%map result = f tid local_c_id c_type in
    (lit_id, result))

let make_local_var_alist (type a) (tid : int)
    (prog : Litmus.Test.Lang.Program.t)
    ~(f : int -> Act_common.C_id.t -> Type.t -> a Or_error.t) :
    (Act_common.Litmus_id.t, a) List.Assoc.t Or_error.t =
  prog |> Named.value |> Function.body_decls
  |> Tx.Or_error.combine_map ~f:(fun (local_c_id, init) ->
         lift_local_var tid local_c_id init ~f)

let make_local_var_alists (type a) (progs : Litmus.Test.Lang.Program.t list)
    ~(f : int -> Act_common.C_id.t -> Type.t -> a Or_error.t) :
    (Act_common.Litmus_id.t, a) List.Assoc.t list Or_error.t =
  Or_error.combine_errors (List.mapi progs ~f:(make_local_var_alist ~f))

let make_alist (type a) (vast : Litmus.Test.t)
    ~(make_global : Act_common.C_id.t -> Type.t -> a Or_error.t)
    ~(make_local : int -> Act_common.C_id.t -> Type.t -> a Or_error.t) :
    (Act_common.Litmus_id.t, a) List.Assoc.t Or_error.t =
  let programs = Litmus.Test.threads vast in
  Or_error.Let_syntax.(
    let%bind global_alist = make_global_var_alist programs ~f:make_global in
    let%map local_alists = make_local_var_alists programs ~f:make_local in
    List.concat (global_alist :: local_alists))

let make_scoped_map (type a) (vast : Litmus.Test.t)
    ~(make_global : Act_common.C_id.t -> Type.t -> a Or_error.t)
    ~(make_local : int -> Act_common.C_id.t -> Type.t -> a Or_error.t) :
    a Ac.Scoped_map.t Or_error.t =
  Or_error.(
    vast
    |> make_alist ~make_global ~make_local
    >>= Map.of_alist_or_error (module Act_common.Litmus_id)
    >>| Ac.Scoped_map.of_litmus_id_map)

let make_set (vast : Litmus.Test.t) :
    Set.M(Act_common.Litmus_id).t Or_error.t =
  (* TODO(@MattWindsor91): this is likely to be inefficient. *)
  Or_error.(
    vast
    |> make_alist
         ~make_global:(fun _ _ -> Or_error.return ())
         ~make_local:(fun _ _ _ -> Or_error.return ())
    >>| List.map ~f:fst
    >>| Set.of_list (module Act_common.Litmus_id))
