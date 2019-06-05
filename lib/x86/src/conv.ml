(* This file is part of 'act'.

   Copyright (c) 2018 by Matt Windsor

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

open Base
module Tx = Travesty_base_exts
module Ac = Act_common

module type S = sig
  type ast

  val convert : ast -> ast Or_error.t
end

module Make (SD : Language_definition.S) (DD : Language_definition.S) =
struct
  type ast = Ast.t

  let swap operands =
    operands |> SD.Dialect.to_src_dst
    |> Option.value_map ~f:DD.Dialect.of_src_dst ~default:operands

  (** [swap_instruction ins] does any swapping of operands needed to convert
      from [SD] to [DD]. *)
  let swap_instruction ins =
    (* Quick checking on godbolt suggests that practically every
       two-argument x86 instruction swaps over, not just ones that read from
       a source and write to a destination.

       This may change. *)
    let swapped_operands = swap ins.Ast.Instruction.operands in
    {ins with Ast.Instruction.operands= swapped_operands}

  (** [convert_jump_operand ins] checks to see if [ins] is a jump and, if
      so, does some syntactic rearranging of the jump's destination.

      See [Dialect.Intf.symbolic_jump_type] for an explanation. *)
  let convert_jump_operand ins =
    if SD.Instruction.is_jump ins then
      match SD.Instruction.abs_operands ins with
      | Act_abstract.Operand.(Bundle.Single (Symbol jsym)) ->
          {ins with operands= [DD.Dialect.make_jump_operand jsym]}
      | _ ->
          ins
    else ins

  let convert_instruction ins =
    ins |> swap_instruction |> convert_jump_operand

  let convert_statement =
    Ast.Statement.On_instructions.map ~f:convert_instruction

  let convert_listing = List.map ~f:convert_statement

  let wrong_dialect_error (actual_dialect : Act_common.Id.t) :
      unit Or_error.t =
    Or_error.error_s
      [%message
        "Tried to convert an AST with a different dialect from the one \
         this converter supports."
          ~expected_dialect:(SD.Dialect.dialect_id : Act_common.Id.t)
          ~actual_dialect:(actual_dialect : Act_common.Id.t)]

  let check_source_dialect (ast : Ast.t) : unit Or_error.t =
    let actual_dialect = Ast.dialect ast in
    Tx.Or_error.unless_m (Ac.Id.equal SD.Dialect.dialect_id actual_dialect)
      ~f:(fun () -> wrong_dialect_error actual_dialect)

  let convert (ast : Ast.t) : Ast.t Or_error.t =
    Or_error.Let_syntax.(
      let%map () = check_source_dialect ast in
      ast
      |> Ast.On_listings.map ~f:convert_listing
      |> Ast.with_dialect_id ~id:DD.Dialect.dialect_id)
end