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

(** Signatures used in redirect maps. *)

open Base

module type Basic_symbol = sig
  type t [@@deriving sexp, equal]

  include Comparable.S with type t := t

  include Stringable.S with type t := t

  val of_c_identifier : C_id.t -> t Or_error.t

  val to_c_identifier : t -> C_id.t Or_error.t
end

module type S = sig
  (** Module of symbols. *)
  module Sym : sig
    type t

    type comparator_witness
  end

  type t [@@deriving sexp_of]
  (** Opaque type of redirect maps. *)

  (** {3 Constructors} *)

  val of_symbol_alist : (Sym.t, Sym.t) List.Assoc.t -> t Or_error.t
  (** [of_symbol_alist alist] tries to lift [alist] into a redirect map. It
      fails if there are duplicate keys. *)

  val identity : unit -> t
  (** [identity s] creates an empty mapping. *)

  (** {3 Mutators} *)

  val redirect : src:Sym.t -> dst:Sym.t -> t -> t
  (** [redirect ~src ~dst rmap] marks [src] as having redirected to [dst] in
      [rmap]. It is safe for [src] and [dst] to be equal; this clears the
      redirection. *)

  val to_string_alist : t -> (string, string) List.Assoc.t
  (** [to_string_alist map] converts [map] into a string-to-string
      associative list. It fails if [map]'s symbols are inexpressible as C
      identifiers. *)

  (** {3 Looking up symbols} *)

  val dest_of_sym : t -> Sym.t -> Sym.t
  (** [dest_of_sym map sym] tries to look up a symbol [sym] in a redirect
      map [map]. It returns [sym] if [sym] has no redirection. *)

  val dest_syms : t -> sources:Set.M(Sym).t -> Set.M(Sym).t
  (** [dest_syms map ~sources] collects all of the destination symbols in
      [map] that are reachable from the source symbols [sources]. This is a
      useful approximation as to which symbols are heap references. *)

  val sources_of_sym : t -> Sym.t -> Set.M(Sym).t
  (** [sources_of_sym rmap dst] gives all of the symbols that map to [dst]
      in [rmap]. *)

  (** {3 Looking up C identifiers} *)

  val dest_of_id : t -> C_id.t -> C_id.t Or_error.t
  (** [dest_of_id map cid] tries to look up a C identifier [cid] in a
      redirect map [map]. It fails if the redirected symbol isn't a valid C
      identifier. *)

  val dest_ids : t -> sources:Set.M(C_id).t -> Set.M(C_id).t Or_error.t
  (** [dest_ids map ~sources] gets the set of C identifiers that are
      reachable, in [map], from identifiers in [sources]. It can fail if any
      of the symbols aren't expressible as identifiers. *)
end
