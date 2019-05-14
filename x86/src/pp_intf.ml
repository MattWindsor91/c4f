(* This file is part of 'act'.

   Copyright (c) 2018, 2019 by Matt Windsor

   (parts (c) 2010-2018 Institut National de Recherche en Informatique et en
   Automatique, Jade Alglave, and Luc Maranget)

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
   USE OR OTHER DEALINGS IN THE SOFTWARE.

   This file derives in part from the Herd7 project
   (https://github.com/herd/herdtools7); its original attribution and
   copyright notice follow. *)

(* the diy toolsuite

   Jade Alglave, University College London, UK.

   Luc Maranget, INRIA Paris-Rocquencourt, France.

   Copyright 2010-present Institut National de Recherche en Informatique et
   en Automatique and the authors. All rights reserved.

   This software is governed by the CeCILL-B license under French law and by
   the rules of distribution of free software. You can use, and/ or
   redistribute the software under the terms of the CeCILL-B license as
   circulated by CEA, CNRS and INRIA at the following URL
   "http://www.cecill.info". We also give a copy in LICENSE.txt. *)

open Ast

(** Signature containing the dialect-specific pretty-printer elements. *)
module type Dialect = sig
  val pp_reg : Reg.t Fmt.t

  val pp_indirect : Indirect.t Fmt.t

  val pp_immediate : Disp.t Fmt.t

  val pp_comment :
    pp:(Format.formatter -> 'a -> unit) -> Format.formatter -> 'a -> unit
  (** [pp_comment ~pp f k] prints a line comment whose body is given by
      invoking [pp] on [k]. *)

  val pp_template_token : string Fmt.t
end

(** Signature of full dialect pretty-printers. *)
module type Printer = sig
  include Dialect

  val pp_reg : Reg.t Fmt.t

  val pp_indirect : Indirect.t Fmt.t

  val pp_immediate : Format.formatter -> Disp.t -> unit

  val pp_location : Location.t Fmt.t

  val pp_bop : Bop.t Fmt.t

  val pp_operand : Operand.t Fmt.t

  val pp_prefix : prefix Fmt.t

  val pp_opcode : Opcode.t Fmt.t
  (** [pp_opcode f op] pretty-prints opcode [op] on formatter [f]. *)

  val pp_oplist : Operand.t list Fmt.t
  (** [pp_oplist f os] pretty-prints operand list [os] on formatter [f]. *)

  val pp_instruction : Instruction.t Fmt.t

  val pp_statement : Statement.t Fmt.t

  val pp : t Fmt.t
  (** [pp f ast] pretty-prints [ast] on formatter [f]. It ignores any
      dialect information. *)
end
