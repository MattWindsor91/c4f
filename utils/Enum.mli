(* This file is part of 'act'.

   Copyright (c) 2018 by Matt Windsor

   Permission is hereby granted, free of charge, to any person
   obtaining a copy of this software and associated documentation
   files (the "Software"), to deal in the Software without
   restriction, including without limitation the rights to use, copy,
   modify, merge, publish, distribute, sublicense, and/or sell copies
   of the Software, and to permit persons to whom the Software is
   furnished to do so, subject to the following conditions:

   The above copyright notice and this permission notice shall be
   included in all copies or substantial portions of the Software.

   THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
   EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
   MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
   NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS
   BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN
   ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN
   CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
   SOFTWARE. *)

(** Helper functions and modules for enums *)

open Core

(** [S] is an interface for enums, compatible with those derived by
   ppx_deriving's enum plugin. *)
module type S = sig
  type t

  (** [min] gets the index of the minimum element. *)
  val min : int

  (** [max] gets the index of the maximum element. *)
  val max : int

  (** [to_enum x] converts [x] to its index. *)
  val to_enum : t -> int

  (** [of_enum k] tries to get the element with index [k]. *)
  val of_enum : int -> t option
end

(** [SSexp] extends [S] with S-expression support,
    compatible with [deriving sexp]. *)
module type SSexp = sig
  include S
  include Sexpable.S with type t := t
end

(** [SSexpTable] extends [SSexp] with a string table. *)
module type SSexpTable = sig
  include SSexp
  include String_table.Table with type t := t
end

(** [Extension] is an extended interface for enums, generated by applying
   [Extend] to an [SSexp]. *)
module type Extension = sig
  type t

  include Comparable.S with type t := t
  include Hashable.S with type t := t
  include Sexpable.S with type t := t

  (** [to_enum x] converts [x] to its index. *)
  val to_enum : t -> int

  (** [of_enum k] tries to get the element with index [k]. *)
  val of_enum : int -> t option

  (** [of_enum_exn k] behaves like [of_enum k], but raises an
     exception if k isn't a valid index. *)
  val of_enum_exn : int -> t

  (** [min_enum] is the enum's [min] value, renamed so as not to
      clash with the comparable version. *)
  val min_enum : int

  (** [max_enum] is the enum's [max] value, renamed so as not to
      clash with the comparable version. *)
  val max_enum : int

  (** [all_list] lists every element in [t] in ascending order. *)
  val all_list : unit -> t list

  (** [all_set] gets the universe set of [t]. *)
  val all_set : unit -> Set.t
end

(** [ExtensionTable] is an extended form of [Extension], including
    properties gleaned from a [StringTable]. *)
module type ExtensionTable = sig
  include Extension
  include String_table.Intf with type t := t
  include Identifiable.S_common with type t := t

  (** [of_string_option] is the same as [of_string] in
     [StringTable.Intf], but renamed so as not to clash with the
     [Stringable] version. *)
  val of_string_option : string -> t option

  (** [pp_set] pretty-prints a set of [t]. *)
  val pp_set : Format.formatter -> Set.t -> unit
end

(** [EnumCompare] generates a [Comparable.S] from an [Enum.SSexp]. *)
module EnumCompare : functor (E : SSexp) -> Comparable.S with type t := E.t

(** [EnumHash] generates a [Hashable.S] from an [Enum.SSexp]. *)
module EnumHash : functor (E : SSexp) -> Hashable.S with type t := E.t

(** [Extend] makes an enum extension. *)
module Extend
  : functor (E : SSexp)
      -> Extension with type t := E.t

(** [Extend] makes an enum extension with table support. *)
module ExtendTable
  : functor (E : SSexpTable)
      -> ExtensionTable with type t := E.t
