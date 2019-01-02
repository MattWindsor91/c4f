(* This file is part of 'act'.

   Copyright (c) 2018, 2019 by Matt Windsor

   Permission is hereby granted, free of charge, to any person obtaining
   a copy of this software and associated documentation files (the
   "Software"), to deal in the Software without restriction, including
   without limitation the rights to use, copy, modify, merge, publish,
   distribute, sublicense, and/or sell copies of the Software, and to
   permit persons to whom the Software is furnished to do so, subject to
   the following conditions:

   The above copyright notice and this permission notice shall be
   included in all copies or substantial portions of the Software.

   THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
   EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
   MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
   NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE
   LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION
   OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION
   WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE. *)

open Base
open Utils

(** [Basic] is the signature common to both
    [Basic_machine] and [Basic_compiler]. *)
module type Basic = sig
  module T : Timing.S
  (** The module to use for timing the various tester passes. *)

  val o : Output.t
  (** [o] tells the tester how to output warnings, errors, and
      other information. *)

  val herd_opt : Herd.t option
  (** [herd_opt], if present, tells the tester how to run Herd. *)

  val sanitiser_passes : Sanitiser_pass.Set.t
  (** [sanitiser_passes] is the set of sanitiser passes the tester
      should use. *)
end

(** [Basic_compiler] contains all the various modules and components
    needed to run tests on one compiler. *)
module type Basic_compiler = sig
  include Basic

  module C : Compiler.S
  (** The compiler interface for this compiler. *)

  module R : Asm_job.Runner
  (** A runner for performing tasks on the assembly generated by
     [C]. *)

  val ps : Pathset.t
  (** [ps] tells the tester where it can find input files, and where
      it should put output files, for this compiler. *)

  include Compiler.With_spec
  (** [Basic_compiler] instances must provide a compiler spec and ID. *)
end

(** User-facing interface for running compiler tests
    on a single compiler. *)
module type Compiler = sig
  val run : Fpath.t list -> Analysis.Compiler.t Or_error.t
  (** [run c_fnames] runs tests on each filename in [c_fnames],
      returning a compiler-level analysis. *)
end


(** [Basic_machine] contains all the various modules and components
    needed to run tests on one machine. *)
module type Basic_machine = sig
  include Basic

  val compiler_from_spec
    :  Compiler.Spec.With_id.t
    -> (module Compiler.S) Or_error.t
  (** [compiler_from_spec cspec] tries to get a [Compiler.S]
      corresponding to [cspec]. *)

  val asm_runner_from_spec
    :  Compiler.Spec.With_id.t
    -> (module Asm_job.Runner) Or_error.t
  (** [asm_runner_from_spec cspec] tries to get an [Asm_job.Runner]
      corresponding to [cspec]'s target architecture. *)
end

module type Machine = sig
  val run
    :  Fpath.t list
    -> Compiler.Spec.Set.t
    -> in_root:Fpath.t
    -> out_root:Fpath.t
    -> Analysis.Machine.t Or_error.t
  (** [run c_fnames specs ~in_root ~out_root] runs tests on each
     filename in [c_fnames], using every compiler in [specs] (presumed
     to belong to the same machine), reading from directories in
     [in_root] and writing to directories in [out_root], and returning
     a machine-level analysis. *)
end
