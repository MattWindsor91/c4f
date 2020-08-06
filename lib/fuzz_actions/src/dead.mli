(* The Automagic Compiler Tormentor

   Copyright (c) 2018--2019 Matt Windsor and contributors

   ACT itself is licensed under the MIT License. See the LICENSE file in the
   project root for more information.

   ACT is based in part on code from the Herdtools7 project
   (https://github.com/herd/herdtools7) : see the LICENSE.herd file in the
   project root for more information. *)

(** Fuzzer flow actions that generate control flows in dead code.

    See also {!If}. *)

(** A fuzzer action that inserts early-out (break, return, etc) statements
    into dead-code. *)
module Early_out :
  Act_fuzz.Action_types.S
    with type Payload.t =
          Act_fir.Early_out.t Act_fuzz.Payload_impl.Insertion.t

(** A fuzzer action that inserts goto statements to random labels into
    dead-code. *)
module Goto :
  Act_fuzz.Action_types.S
    with type Payload.t = Act_common.C_id.t Act_fuzz.Payload_impl.Insertion.t