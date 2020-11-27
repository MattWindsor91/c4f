(* The Automagic Compiler Tormentor

   Copyright (c) 2018, 2019, 2020 Matt Windsor and contributors

   ACT itself is licensed under the MIT License. See the LICENSE file in the
   project root for more information.

   ACT is based in part on code from the Herdtools7 project
   (https://github.com/herd/herdtools7) : see the LICENSE.herd file in the
   project root for more information. *)

(** Specialised Quickcheck generators for addresses *)

open Import

(** Type of lvalue generators. *)
module type S = sig
  type t = Fir.Address.t [@@deriving sexp_of, quickcheck]
end

(** Generates random addresses, constrained over the variables in the given
    environment. *)
module On_env (E : Fir.Env_types.S) : S

(** Generates addresses over the given typing environment that have the type
    'atomic_int*'. *)
module Atomic_int_pointers (E : Fir.Env_types.S) : S

(** Generates addresses over the given typing environment that have the type
    'atomic_bool*'. *)
module Atomic_bool_pointers (E : Fir.Env_types.S) : S
