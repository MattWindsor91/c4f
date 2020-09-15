(* The Automagic Compiler Tormentor

   Copyright (c) 2018--2020 Matt Windsor and contributors

   ACT itself is licensed under the MIT License. See the LICENSE file in the
   project root for more information.

   ACT is based in part on code from the Herdtools7 project
   (https://github.com/herd/herdtools7) : see the LICENSE.herd file in the
   project root for more information. *)

(** Consumers of fuzzer subject paths.

    These take the form of functions that accept paths and tests, and perform
    actions on the part of that subject referenced by the path. *)

open Base

val consume_with_flags :
     ?filter:Path_filter.t
  -> Subject.Test.t
  -> path:Path.t Path_flag.Flagged.t
  -> action:Path_kind.With_action.t
  -> Subject.Test.t Or_error.t
(** [consume_with_flags ?filter target ~path ~action] consumes [path] over [target],
    performing [action] at the end of it.

    If [filter] is present, the consumer will check that the path satisfies
    the path filter. This is the same check as used in {!Path_producers}; its
    use here is to safeguard against broken path production or replaying of
    ill-formed traces.

    It adds to the path filter the requirement that the flags attached to
    [path] must hold. This safeguards against traces mistakenly attributing
    flags, for instance. *)
