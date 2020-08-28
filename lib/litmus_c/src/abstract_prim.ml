(* The Automagic Compiler Tormentor

   Copyright (c) 2018--2020 Matt Windsor and contributors

   ACT itself is licensed under the MIT License. See the LICENSE file in the
   project root for more information.

   ACT is based in part on code from the Herdtools7 project
   (https://github.com/herd/herdtools7) : see the LICENSE.herd file in the
   project root for more information. *)

open Core_kernel (* for Fqueue *)

open struct
  module Ac = Act_common
  module Tx = Travesty_base_exts
  module Fir = Act_fir
  module Named = Ac.C_named
end

let constant : Ast_basic.Constant.t -> Fir.Constant.t Or_error.t = function
  | Integer k ->
      Or_error.return (Fir.Constant.int k)
  | Char _ | Float _ ->
      Or_error.error_string "Unsupported constant type"

let defined_types : (Ac.C_id.t, Fir.Type.Basic.t) List.Assoc.t Lazy.t =
  lazy
    Fir.Type.Basic.
      [ (Ac.C_id.of_string "atomic_bool", bool ~is_atomic:true ())
      ; (Ac.C_id.of_string "atomic_int", int ~is_atomic:true ())
      ; (Ac.C_id.of_string "bool", bool ()) ]

let defined_type_to_basic (t : Ac.C_id.t) : Fir.Type.Basic.t Or_error.t =
  t
  |> List.Assoc.find ~equal:Ac.C_id.equal (Lazy.force defined_types)
  |> Result.of_option
       ~error:
         (Error.create_s
            [%message "Unknown defined type" ~got:(t : Ac.C_id.t)])

let partition_qualifiers :
       [> Ast.Decl_spec.t] list
    -> [> Ast.Type_spec.t] list
       * [> Ast_basic.Storage_class_spec.t | Ast_basic.Type_qual.t] list =
  List.partition_map ~f:(function
    | #Ast.Type_spec.t as ts ->
        First ts
    | #Ast_basic.Storage_class_spec.t as ss ->
        Second ss
    | #Ast_basic.Type_qual.t as qs ->
        Second qs)

let type_specs_to_basic (specs : [> Ast.Type_spec.t] list) :
    Fir.Type.Basic.t Or_error.t =
  Or_error.Let_syntax.(
    match%bind Tx.List.one specs with
    | `Int ->
        return (Fir.Type.Basic.int ())
    | `Defined_type t ->
        defined_type_to_basic t
    | #Ast.Type_spec.t as spec ->
        Or_error.error_s
          [%message
            "This type isn't supported (yet)" ~got:(spec : Ast.Type_spec.t)])

let qualifier_to_flags :
       [> Ast_basic.Storage_class_spec.t | Ast_basic.Type_qual.t]
    -> bool Or_error.t = function
  | `Volatile ->
      Ok true
  | #Ast_basic.Type_qual.t as qual ->
      Or_error.error_s
        [%message
          "This type qualifier isn't supported (yet)"
            ~got:(qual : Ast_basic.Type_qual.t)]
  | #Ast_basic.Storage_class_spec.t as spec ->
      Or_error.error_s
        [%message
          "This storage-class specifier isn't supported (yet)"
            ~got:(spec : Ast_basic.Storage_class_spec.t)]

let qualifiers_to_flags
    (quals : [> Ast_basic.Storage_class_spec.t | Ast_basic.Type_qual.t] list)
    : bool Or_error.t =
  Or_error.Let_syntax.(
    (* TODO(@MattWindsor91): other qualifiers? *)
    let%map vs = Tx.Or_error.combine_map quals ~f:qualifier_to_flags in
    List.exists vs ~f:Fn.id)

let qualifiers_to_type (quals : [> Ast.Decl_spec.t] list)
    ~(is_pointer : bool) : Fir.Type.t Or_error.t =
  let tspecs, rquals = partition_qualifiers quals in
  Or_error.Let_syntax.(
    let%map basic = type_specs_to_basic tspecs
    and is_volatile = qualifiers_to_flags rquals in
    Fir.Type.make basic ~is_pointer ~is_volatile)

let declarator_to_id :
    Ast.Declarator.t -> (Act_common.C_id.t * bool) Or_error.t = function
  | {pointer= Some [[]]; direct= Id id} ->
      Or_error.return (id, true)
  | {pointer= Some _; _} as decl ->
      Or_error.error_s
        [%message
          "Complex pointers not supported yet"
            ~declarator:(decl : Ast.Declarator.t)]
  | {pointer= None; direct= Id id} ->
      Or_error.return (id, false)
  | x ->
      Or_error.error_s
        [%message
          "Unsupported direct declarator"
            ~got:(x.direct : Ast.Direct_declarator.t)]

let identifier_to_constant (id : Ac.C_id.t) : Fir.Constant.t option =
  match Ac.C_id.to_string id with
  | "true" ->
      Some Fir.Constant.truth
  | "false" ->
      Some Fir.Constant.falsehood
  | _ ->
      None

let not_constant (x : Ast.Expr.t) : Fir.Constant.t Or_error.t =
  Or_error.error_s
    [%message "Expression not supported (must be constant)" (x : Ast.Expr.t)]

let value_of_initialiser : Ast.Initialiser.t -> Fir.Constant.t Or_error.t =
  function
  | Assign (Constant v) ->
      (* TODO(@MattWindsor91): Boolean initialisers aren't covered by this
         case, as C99 Boolean 'constant's are identifiers. *)
      constant v
  | Assign (Identifier k) -> (
    match identifier_to_constant k with
    | Some k ->
        Ok k
    | None ->
        not_constant (Identifier k) )
  | Assign x ->
      not_constant x
  | List _ ->
      Or_error.error_string "List initialisers not supported"

let decl (d : Ast.Decl.t) : Fir.Initialiser.t Named.t Or_error.t =
  Or_error.Let_syntax.(
    let%bind idecl = Tx.List.one d.declarator in
    let%bind name, is_pointer = declarator_to_id idecl.declarator in
    let%bind ty = qualifiers_to_type d.qualifiers ~is_pointer in
    let%bind init =
      Result.of_option idecl.initialiser
        ~error:(Error.of_string "Empty initialisers not supported")
    in
    let%map value = value_of_initialiser init in
    Named.make ~name (Fir.Initialiser.make ~ty ~value))

let param_decl : Ast.Param_decl.t -> Fir.Type.t Named.t Or_error.t = function
  | {declarator= `Abstract _; _} ->
      Or_error.error_string "Abstract parameter declarators not supported"
  | {qualifiers; declarator= `Concrete declarator} ->
      Or_error.Let_syntax.(
        let%bind name, is_pointer = declarator_to_id declarator in
        let%map ty = qualifiers_to_type qualifiers ~is_pointer in
        Named.make ty ~name)

let rec expr_to_lvalue : Ast.Expr.t -> Fir.Lvalue.t Or_error.t = function
  | Identifier id ->
      Or_error.return (Fir.Lvalue.variable id)
  | Brackets expr ->
      expr_to_lvalue expr
  | Prefix (`Deref, expr) ->
      Or_error.(expr |> expr_to_lvalue >>| Fir.Lvalue.deref)
  | ( Prefix _
    | Postfix _
    | Binary _
    | Ternary _
    | Cast _
    | Call _
    | Subscript _
    | Field _
    | Sizeof_type _
    | String _
    | Constant _ ) as e ->
      Or_error.error_s
        [%message "Expected an lvalue here" ~got:(e : Ast.Expr.t)]

let rec expr_to_address : Ast.Expr.t -> Fir.Address.t Or_error.t = function
  | Prefix (`Ref, expr) ->
      Or_error.(expr |> expr_to_address >>| Fir.Address.ref)
  | expr ->
      Or_error.(expr |> expr_to_lvalue >>| Fir.Address.lvalue)

let lvalue_to_identifier (lv : Fir.Lvalue.t) : Act_common.C_id.t Or_error.t =
  if Fir.Lvalue.is_deref lv then
    Or_error.error_s
      [%message "Expected identifier" ~got:(lv : Fir.Lvalue.t)]
  else Or_error.return (Fir.Lvalue.variable_of lv)

let expr_to_identifier (expr : Ast.Expr.t) : Act_common.C_id.t Or_error.t =
  Or_error.(expr |> expr_to_lvalue >>= lvalue_to_identifier)

let expr_to_memory_order (expr : Ast.Expr.t) : Fir.Mem_order.t Or_error.t =
  Or_error.Let_syntax.(
    let%bind id = expr_to_identifier expr in
    id |> Ac.C_id.to_string |> Fir.Mem_order.of_string_option
    |> Result.of_option
         ~error:
           (Error.create_s
              [%message
                "Unsupported memory order" ~got:(id : Act_common.C_id.t)]))

let sift_decls (maybe_decl_list : ([> `Decl of 'd] as 'a) list) :
    ('d list * 'a list) Or_error.t =
  Or_error.(
    Tx.List.With_errors.fold_m maybe_decl_list
      ~init:(Fqueue.empty, Fqueue.empty) ~f:(fun (decls, rest) -> function
      | `Decl d ->
          if Fqueue.is_empty rest then return (Fqueue.enqueue decls d, rest)
          else error_string "Declarations must go before code."
      | item ->
          return (decls, Fqueue.enqueue rest item))
    >>| fun (decls, rest) -> (Fqueue.to_list decls, Fqueue.to_list rest))