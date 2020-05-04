(* The Automagic Compiler Tormentor

   Copyright (c) 2018--2020 Matt Windsor and contributors

   ACT itself is licensed under the MIT License. See the LICENSE file in the
   project root for more information.

   ACT is based in part on code from the Herdtools7 project
   (https://github.com/herd/herdtools7) : see the LICENSE.herd file in the
   project root for more information. *)

open Base
module Ast = Act_c_lang.Ast

let atomic = Reify_atomic.reify_stm ~expr:Reify_expr.reify

let assign (asn : Assign.t) : Ast.Stm.t =
  let l = Assign.lvalue asn in
  let r = Assign.rvalue asn in
  Expr (Some Reify_expr.(Binary (Reify_prim.lvalue l, `Assign, reify r)))

let lift_stms (type stm) (stm : stm -> Ast.Stm.t) (xs : stm list) :
    Ast.Compound_stm.t =
  List.map ~f:(fun s -> `Stm (stm s)) xs

let block (type meta stm) (stm : stm -> Ast.Stm.t) (b : (meta, stm) Block.t)
    : Ast.Stm.t =
  Compound (lift_stms stm (Block.statements b))

let ne_block (type meta stm) (stm : stm -> Ast.Stm.t)
    (b : (meta, stm) Block.t) : Ast.Stm.t option =
  if Block.is_empty b then None else Some (block stm b)

let nop (_ : 'meta) : Ast.Stm.t = Ast.Stm.Expr None

let early_out : Early_out.t -> Ast.Stm.t = function
  | Break ->
      Ast.Stm.Break
  | Continue ->
      Ast.Stm.Continue
  | Return ->
      Ast.Stm.Return None

let label (l : Act_common.C_id.t) : Ast.Stm.t =
  (* This might need revisiting later. *)
  Label (Normal l, Expr None)

let goto (l : Act_common.C_id.t) : Ast.Stm.t = Goto l

let procedure_call (c : Call.t) : Ast.Stm.t =
  Ast.Stm.Expr
    (Some
       (Ast.Expr.Call
          { func= Identifier (Call.function_id c)
          ; arguments= List.map ~f:Reify_expr.reify (Call.arguments c) }))

let prim ((_, p) : _ * Prim_statement.t) : Ast.Stm.t =
  Prim_statement.reduce p ~assign ~atomic ~early_out ~procedure_call ~label
    ~goto ~nop

let rec reify : _ Statement.t -> Ast.Stm.t =
  Statement.reduce ~prim ~if_stm ~while_loop

and if_stm (ifs : _ Statement.If.t) : Ast.Stm.t =
  If
    { cond= Reify_expr.reify (Statement.If.cond ifs)
    ; t_branch= block reify (Statement.If.t_branch ifs)
    ; f_branch= ne_block reify (Statement.If.f_branch ifs) }

and while_loop (loop : _ Statement.While.t) : Ast.Stm.t =
  let cond = Reify_expr.reify (Statement.While.cond loop)
  and body = block reify (Statement.While.body loop) in
  match Statement.While.kind loop with
  | `While ->
      While (cond, body)
  | `Do_while ->
      Do_while (body, cond)

(* Yay, value restriction... *)
let reify_compound (type meta) (m : meta Statement.t list) :
    Ast.Compound_stm.t =
  lift_stms reify m
