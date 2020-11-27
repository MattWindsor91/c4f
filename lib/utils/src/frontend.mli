(* The Automagic Compiler Tormentor

   Copyright (c) 2018, 2019, 2020 Matt Windsor and contributors

   ACT itself is licensed under the MIT License. See the LICENSE file in the
   project root for more information.

   ACT is based in part on code from the Herdtools7 project
   (https://github.com/herd/herdtools7) : see the LICENSE.herd file in the
   project root for more information. *)

open Sedlexing

module Error_range : sig
  type t = Lexing.position * Lexing.position [@@deriving sexp_of]
end

exception LexError of string * Error_range.t

val lex_error : string -> lexbuf -> 'a
(** [lex_error error lexbuf] raises a [LexError] with the given error message
    and lexbuf. *)

(** [Basic] is the signature that language frontends must implement to use
    [Make]. *)
module type Basic = sig
  type ast

  module I : MenhirLib.IncrementalEngine.INCREMENTAL_ENGINE

  val lex : lexbuf -> I.token

  val parse : Lexing.position -> ast I.checkpoint

  val message : int -> string
end

(** [Make] lifts an instance of [B] into a frontend. *)
module Make (B : Basic) : Plumbing.Loadable_types.S with type t = B.ast
