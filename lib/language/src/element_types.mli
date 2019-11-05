(* This file is part of 'act'.

   Copyright (c) 2018, 2019 by Matt Windsor

   Permission is hereby granted, free of charge, to any person obtaining a
   copy of this software and associated documentation files (the "Software"),
   to deal in the Software without restriction, including without limitation
   the rights to use, copy, modify, merge, publish, distribute, sublicense,
   and/or sell copies of the Software, and to permit persons to whom the
   Software is furnished to do so, subject to the following conditions:

   The above copyright notice and this permission notice shall be included in
   all copies or substantial portions of the Software.

   THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
   IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
   FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL
   THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
   LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
   FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER
   DEALINGS IN THE SOFTWARE. *)

open Base

module type Basic = sig
  module Symbol : Pretty_printer.S

  module Location : Pretty_printer.S

  module Instruction : Pretty_printer.S

  module Statement : Pretty_printer.S
end

module type S = sig
  type ins
  (** Instructions *)

  type loc
  (** Locations *)

  type stm
  (** Statements *)

  type sym
  (** Symbols *)

  type t =
    | Instruction of ins
    | Location of loc
    | Operands of ins
    | Statement of stm
    | Symbol of sym

  include Pretty_printer.S with type t := t

  val type_name : t -> string
  (** [type_name elt] gets a descriptive name for [elt]'s type. *)
end
