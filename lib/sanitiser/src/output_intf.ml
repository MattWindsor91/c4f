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

module type Basic = sig
  (** Type of raw program listings. *)
  type listing

  (** Type of sanitiser warnings. *)
  type warn

  (** Traversable container used to store programs. *)
  type 'l pc

  (** Type of redirect maps. *)
  type rmap
end

(** Signature of sanitiser output modules. *)
module type S = sig
  include Basic

  (** [t] is the type of (successful) sanitiser output. *)
  type t

  (** [Program] is the abstract data type of a single program's sanitiser
      output. *)
  module Program : sig
    type t

    val listing : t -> listing
    (** [listing p] gets the final sanitised program listing. *)

    val warnings : t -> warn list
    (** [warnings t] gets the warning list for this program. *)

    val symbol_table : t -> Act_abstract.Symbol.Table.t
    (** [symbol_table t] gets the program's final symbol table. *)

    val make :
         ?warnings:warn list
      -> listing:listing
      -> symbol_table:Act_abstract.Symbol.Table.t
      -> unit
      -> t
    (** [make ?warnings ~listing ~symbol_table] makes a program output with
        the warnings set [warnings], program listing [listing], and final
        symbol table [symbol_table]. *)
  end

  val programs : t -> Program.t pc
  (** [programs t] gets the final sanitised programs. *)

  val redirects : t -> rmap
  (** [redirects t] gets the final mapping from C-level symbols to the
      symbols in [programs t]. *)

  val make : programs:Program.t pc -> redirects:rmap -> t
  (** [make ~programs ~redirects] makes an output using the given container
      of programs [programs] and redirects map [redirects]. *)
end
