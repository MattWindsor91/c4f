(* The Automagic Compiler Tormentor

   Copyright (c) 2018--2020 Matt Windsor and contributors

   ACT itself is licensed under the MIT License. See the LICENSE file in the
   project root for more information.

   ACT is based in part on code from the Herdtools7 project
   (https://github.com/herd/herdtools7) : see the LICENSE.herd file in the
   project root for more information. *)

open Base

open struct
  module Ac = Act_common
  module Ast = Act_c_lang.Ast
end

let to_initialiser (value : Constant.t) : Ast.Initialiser.t =
  Assign (Reify_expr.constant value)

let basic_type_to_spec (b : Type.Basic.t) : [> Ast.Type_spec.t] =
  match Type.Basic.(prim b, is_atomic b) with
  | Int, false ->
      `Int
  | Int, true ->
      `Defined_type (Ac.C_id.of_string "atomic_int")
  | Bool, false ->
      `Defined_type (Ac.C_id.of_string "bool")
  | Bool, true ->
      `Defined_type (Ac.C_id.of_string "atomic_bool")

let type_to_specs (ty : Type.t) : [> Act_c_lang.Ast.Decl_spec.t] list =
  (* We translate the level of indirection separately, in [type_to_pointer]. *)
  List.filter_opt
    [ Some (basic_type_to_spec (Type.basic_type ty))
    ; Option.some_if (Type.is_volatile ty) `Volatile ]

let type_to_pointer (ty : Type.t) : Act_c_lang.Ast_basic.Pointer.t option =
  (* We translate the actual underlying type separately, in [type_to_specs]. *)
  Option.some_if (Type.is_pointer ty) [[]]

let id_declarator (ty : Type.t) (id : Ac.C_id.t) : Ast.Declarator.t =
  {pointer= type_to_pointer ty; direct= Id id}

let decl (init : Initialiser.t Ac.C_named.t) : Ast.Decl.t =
  let id = Ac.C_named.name init in
  let elt = Ac.C_named.value init in
  let ty = Initialiser.ty elt in
  let value = Initialiser.value elt in
  { qualifiers= type_to_specs ty
  ; declarator=
      [ { declarator= id_declarator ty id
        ; initialiser= Option.map ~f:to_initialiser value } ] }
