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

(** [Abstract_symbol] contains types and utilities for abstracted symbols. *)

open Base
open Act_utils

module M = String
(** Symbols are strings. *)

include module type of M

(** [Sort] is a module containing an enumeration of symbol sorts. *)
module Sort : sig
  type t = Jump | Heap | Label

  include Enum_types.Extension_table with type t := t
end

(** [Table] is a module concerning symbol tables: many-to-many mappings
    between symbols and sorts. *)
module Table : sig
  type elt = t

  type t

  val empty : t
  (** [empty] is the empty table. *)

  val of_sets : (Set.M(M).t, Sort.t) List.Assoc.t -> t
  (** [of_sets sets] expands a symbol-set-to-sort associative list into a
      [t]. *)

  val add : t -> elt -> Sort.t -> t
  (** [add tbl sym sort] registers [sym] as a symbol with sort [sort] in
      [tbl], returning a new table. *)

  val remove : t -> elt -> Sort.t -> t
  (** [remove tbl sym sort] de-registers [sym] as a symbol with sort [sort]
      in [tbl], returning a new table.

      If [sym] also maps to another sort, those mappings remain. *)

  val set_of_sorts : t -> Set.M(Sort).t -> Set.M(M).t
  (** [set_of_sorts tbl sorts] returns all symbols in [tbl] with a sort in
      [sorts], as a symbol set. *)

  val set_of_sort : t -> Sort.t -> Set.M(M).t
  (** [set_of_sort tbl sort] returns all symbols in [tbl] with sort [sort],
      as a symbol set. *)

  val set : t -> Set.M(M).t
  (** [set tbl] returns all symbols in [tbl] as a symbol set. *)

  val mem : t -> ?sort:Sort.t -> elt -> bool
  (** [mem tbl ?sort symbol] checks whether [symbol] is in [tbl]. If [sort]
      is present, we additionally require that [symbol] has sort [sort] in
      [tbl]. *)

  include Tabulator.Tabular with type data := t
  (** Tables can be turned into [Tabulator] instances. *)

  include Tabulator.Tabular_extensions with type data := t
  (** They can also, therefore, be pretty-printed as tables. *)
end
