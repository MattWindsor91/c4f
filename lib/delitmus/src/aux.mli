(* The Automagic Compiler Tormentor

   Copyright (c) 2018--2019 Matt Windsor and contributors

   ACT itself is licensed under the MIT License. See the LICENSE file in the
   project root for more information.

   ACT is based in part on code from the Herdtools7 project
   (https://github.com/herd/herdtools7) : see the LICENSE.herd file in the
   project root for more information. *)

(** Auxiliary information generated by a de-litmusification round.

    This combines both the auxiliary information from the litmus test itself,
    as well as information about the variables and thread IDs that were in
    use in the body of the Litmus test. *)

type t [@@deriving equal, yojson]

(** {2 Constructors} *)

val make :
     ?litmus_header:Act_c_mini.Constant.t Act_litmus.Header.t
  -> var_map:Var_map.t
  -> num_threads:int
  -> unit
  -> t

val empty : t

(** {2 Accessors} *)

val litmus_header : t -> Act_c_mini.Constant.t Act_litmus.Header.t
(** [litmus_header aux] gets the header of the Litmus test from which this
    auxiliary record was generated. *)

val var_map : t -> Var_map.t

val symbols : t -> string list

include Plumbing.Loadable_types.S with type t := t
