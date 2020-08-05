(* The Automagic Compiler Tormentor

   Copyright (c) 2018--2019 Matt Windsor and contributors

   ACT itself is licensed under the MIT License. See the LICENSE file in the
   project root for more information.

   ACT is based in part on code from the Herdtools7 project
   (https://github.com/herd/herdtools7) : see the LICENSE.herd file in the
   project root for more information. *)

(** Actions that introduce, or rearrange, loops. *)

(** {1 Insertion} *)

(** This action inserts a while loop with a known-false expression in a
    random statement position; its body begins empty but is marked as
    dead-code. *)
module While_insert_false :
  Act_fuzz.Action_types.S
    with type Payload.t =
          Act_fir.Expression.t Act_fuzz.Payload_impl.Insertion.t

(** {1 Surround statements in do-while loops}

    This action removes a sublist of statements from the program, replacing
    them with a `do... while` statement containing some transformation of the
    removed statements.

    See also {!If_actions.Surround}. *)
module Surround :
  Act_fuzz.Action_types.S
    with type Payload.t = Act_fuzz.Payload_impl.Cond_surround.t
