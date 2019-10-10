(* The Automagic Compiler Tormentor

   Copyright (c) 2018--2019 Matt Windsor and contributors

   ACT itself is licensed under the MIT License. See the LICENSE file in the
   project root for more information.

   ACT is based in part on code from the Herdtools7 project
   (https://github.com/herd/herdtools7) : see the LICENSE.herd file in the
   project root for more information. *)

(** A specialisation of {!Act_litmus.Aux} that includes JSON serialisation
    and deserialisation. *)

type t = Constant.t Act_litmus.Aux.t [@@deriving equal, yojson]
