(* The Automagic Compiler Tormentor

   Copyright (c) 2018, 2019, 2020 Matt Windsor and contributors

   ACT itself is licensed under the MIT License. See the LICENSE file in the
   project root for more information.

   ACT is based in part on code from the Herdtools7 project
   (https://github.com/herd/herdtools7) : see the LICENSE.herd file in the
   project root for more information. *)

(** Producer of 'stub' Litmus tests, which call into an implementation.

    The idea of this module is to facilitate test set-ups with harness
    generators such as Litmus that inline the thread bodies given to them; to
    hide things like return statements and untracked variables from those
    generators, we can delitmusify the thread bodies into a C file, produce a
    stub test with this module, and link the bodies into the generated
    harness. *)

open Base

val make : Aux.t -> Act_fir.Litmus.Test.t Or_error.t
(** [make aux] tries to produce a stub for the delitmus run described by
    [aux]. *)

module Filter : sig
  val run : Plumbing.Input.t -> Plumbing.Output.t -> unit Or_error.t
  (** [run input output] runs [make] over the auxiliary input incoming as
      JSON over [input], dumping the stub to [output]. *)
end
