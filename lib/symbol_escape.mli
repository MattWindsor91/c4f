(* This file is part of 'act'.

   Copyright (c) 2018, 2019 by Matt Windsor

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

(** [act]'s Herd-safe symbol escaper.

    This module exposes several functions that mangle a language
    symbol to remove any characters that tools such as Herd and Litmus
    find hard to parse: underscores, dollar signs, and
    so on.  The mangling isn't guaranteed to correspond to any
    'standard' escaping of these characters, but aims to be vaguely
    human-readable and injective.
 *)

open Base

(** [escape_string s] performs symbol escaping on the string [s]. *)
val escape_string : string -> string

(** Builds symbol escaping functions over a language symbol type. *)
module Make (S : Language_symbol.S) : sig
  (** [escape s] performs symbol escaping on the symbol [s]. *)
  val escape : S.t -> S.t

  (** [escape_rmap map] tries to escape every symbol in the redirect
     map [map], by applying redirects from each existing redirect
     target to its {{!escape}escape}d equivalent. *)
  val escape_rmap : S.R_map.t -> S.R_map.t Or_error.t
end