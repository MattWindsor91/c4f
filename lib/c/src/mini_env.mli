(* This file is part of 'act'.

   Copyright (c) 2018, 2019 by Matt Windsor

   Permission is hereby granted, free of charge, to any person obtaining a
   copy of this software and associated documentation files (the
   "Software"), to deal in the Software without restriction, including
   without limitation the rights to use, copy, modify, merge, publish,
   distribute, sublicense, and/or sell copies of the Software, and to permit
   persons to whom the Software is furnished to do so, subject to the
   following conditions:

   The above copyright notice and this permission notice shall be included
   in all copies or substantial portions of the Software.

   THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS
   OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
   MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN
   NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM,
   DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR
   OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE
   USE OR OTHER DEALINGS IN THE SOFTWARE. *)

(** Mini-model: variable typing environments

    Large parts of the mini-model's type checking and program fragment
    generation functionality depends on the existence of a typing
    environment mapping variable names to their
    {{!Mini_type} mini-model types}. This module, and its accompanying
    {{!Mini_env_intf} intf module}, provide a modular interface for these
    typing environments.

    Usually, the typing environments will be built as first-class modules,
    generated by applying {{!Make} Make} to a lifted map value. *)

open Act_utils

include module type of Mini_env_intf

(** [Make (E)] extends a basic environment module with various functions and
    generators. *)
module Make (E : Basic) : S

(** {2 Test environments}

    These (lazily-evaluated) values contain simple pre-populated test
    environments that can be used for expects tests, as well as Quickcheck
    tests that depend on a well-formed environment. *)

val test_env : Mini_type.t C_identifier.Map.t Lazy.t
(** [test_env] is an environment used for testing the various
    environment-sensitive operations. *)

val test_env_mod : (module S) Lazy.t
(** {{!test_env} test_env} packaged as a first-class module. *)

val test_env_atomic_ptrs_only : Mini_type.t C_identifier.Map.t Lazy.t
(** [test_env_atomic_ptrs_only] is an environment that contains only
    variables of type 'atomic_int*'. *)

val test_env_atomic_ptrs_only_mod : (module S) Lazy.t
(** {{!test_env_atomic_ptrs_only} test_env_atomic_ptrs_only} packaged as a
    first-class module. *)

val empty_env_mod : (module S) Lazy.t
(** A first-class module containing a completely empty environment. *)
