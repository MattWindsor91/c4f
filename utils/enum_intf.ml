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

open Core_kernel

(** [S] is an interface for enums, compatible with those derived by
    ppx_deriving's enum plugin. *)
module type S = sig
  type t

  val min : int
  (** [min] gets the index of the minimum element. *)

  val max : int
  (** [max] gets the index of the maximum element. *)

  val to_enum : t -> int
  (** [to_enum x] converts [x] to its index. *)

  val of_enum : int -> t option
  (** [of_enum k] tries to get the element with index [k]. *)
end

(** [S_enumerate] is a different interface for enums, compatible with those
    derived by Jane Street's [enumerate]. *)
module type S_enumerate = sig
  type t

  include Equal.S with type t := t

  val all : t list
  (** [all] gets a list of all elements in [t]. *)
end

(** [S_sexp] extends [S] with S-expression support, compatible with
    [deriving sexp]. *)
module type S_sexp = sig
  include S

  include Sexpable.S with type t := t
end

(** [S_table] extends [S] with a string table.

    [S_table] doesn't contain [Sexpable], as we derive it from the string
    table itself. *)
module type S_table = sig
  include S

  include String_table.Table with type t := t
end

(** [Extension] is an extended interface for enums, generated by applying
    [Extend] to an [SSexp]. *)
module type Extension = sig
  type t

  include Comparable.S with type t := t

  include Hashable.S with type t := t

  include Sexpable.S with type t := t

  include Quickcheck.S with type t := t

  val to_enum : t -> int
  (** [to_enum x] converts [x] to its index. *)

  val of_enum : int -> t option
  (** [of_enum k] tries to get the element with index [k]. *)

  val of_enum_exn : int -> t
  (** [of_enum_exn k] behaves like [of_enum k], but raises an exception if k
      isn't a valid index. *)

  val min_enum : int
  (** [min_enum] is the enum's [min] value, renamed so as not to clash with
      the comparable version. *)

  val max_enum : int
  (** [max_enum] is the enum's [max] value, renamed so as not to clash with
      the comparable version. *)

  val all_list : unit -> t list
  (** [all_list] lists every element in [t] in ascending order. *)

  val all_set : unit -> Set.t
  (** [all_set] gets the universe set of [t]. *)
end

(** [Extension_table] is an extended form of [Extension], including
    properties gleaned from a [String_table]. *)
module type Extension_table = sig
  include Extension

  include String_table.S with type t := t

  include Identifiable.S_common with type t := t

  val of_string_option : string -> t option
  (** [of_string_option] is the same as [of_string] in [StringTable.Intf],
      but renamed so as not to clash with the [Stringable] version. *)

  val pp_set : Format.formatter -> Set.t -> unit
  (** [pp_set] pretty-prints a set of [t]. *)
end

(** [Enum] is the part of this file re-exported as [Enum.mli]. *)
module type Enum = sig
  module type S = S

  module type S_enumerate = S_enumerate

  module type S_sexp = S_sexp

  module type S_table = S_table

  module type Extension = Extension

  module type Extension_table = Extension_table

  (** [Make_from_enumerate] makes an [S] from an [S_enumerate]. *)
  module Make_from_enumerate (E : S_enumerate) : S with type t := E.t

  (** [Make_comparable] generates a [Comparable.S] from an [Enum.S_sexp]. *)
  module Make_comparable (E : S_sexp) : Comparable.S with type t := E.t

  (** [Make_hashable] generates a [Hashable.S] from an [Enum.S_sexp]. *)
  module Make_hashable (E : S_sexp) : Hashable.S with type t := E.t

  (** [Extend] makes an enum extension. *)
  module Extend (E : S_sexp) : Extension with type t := E.t

  (** [Extend] makes an enum extension with table support. *)
  module Extend_table (E : S_table) : Extension_table with type t := E.t
end
