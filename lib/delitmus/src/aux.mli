(* The Automagic Compiler Tormentor

   Copyright (c) 2018, 2019, 2020 Matt Windsor and contributors

   ACT itself is licensed under the MIT License. See the LICENSE file in the
   project root for more information.

   ACT is based in part on code from the Herdtools7 project
   (https://github.com/herd/herdtools7) : see the LICENSE.herd file in the
   project root for more information. *)

(** Auxiliary information generated by a de-litmusification round.

    This combines both the auxiliary information from the litmus test itself,
    as well as information about the variables and thread IDs that were in
    use in the body of the Litmus test. *)

open Base
open Import

type t [@@deriving equal, yojson]

(** {1 Constructors} *)

val make :
     ?litmus_header:Fir.Constant.t Litmus.Header.t
  -> ?function_map:Function_map.t
  -> ?var_map:Var_map.t
  -> unit
  -> t
(** [make ?litmus_header ?function_map ?var_map ()] builds a delitmus aux
    record for a test with variable migration map [var_map] (empty by
    default), function migration map [function_map] (empty by default), and
    Litmus test header [litmus_header] (empty by default). *)

val empty : t
(** [empty] is the empty aux record. *)

(** {1 Accessors} *)

val litmus_header : t -> Fir.Constant.t Litmus.Header.t
(** [litmus_header aux] gets the header of the Litmus test from which this
    auxiliary record was generated. *)

val function_map : t -> Function_map.t
(** [function_map aux] gets the mapping from Litmus functions to C functions
    from [aux]. *)

val var_map : t -> Var_map.t

(** {1 Loading and storing delitmus aux records} *)

include Plumbing.Loadable_types.S with type t := t

(** The auxiliary information can be pretty-printed; doing so is guaranteed
    to output its JSON reading in a human-readable manner. *)

include Pretty_printer.S with type t := t
