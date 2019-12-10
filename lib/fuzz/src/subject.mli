(* The Automagic Compiler Tormentor

   Copyright (c) 2018--2019 Matt Windsor and contributors

   ACT itself is licensed under the MIT License. See the LICENSE file in the
   project root for more information.

   ACT is based in part on code from the Herdtools7 project
   (https://github.com/herd/herdtools7) : see the LICENSE.herd file in the
   project root for more information. *)

(** Fuzzer: subjects of fuzzing

    This module contains types for thread and litmus tests that are looser
    and lighter than their {!Act_c_mini} versions, and more suited to
    mutation.

    Many of these types take a metadata type parameter, but this is mostly
    just to support creating path types over them; in practice, the only
    metadata type used in the fuzzer is {!Metadata.t}. *)

open Base

(** {1 Shorthand for mini-C constructs with subject metadata}

    Compared to the metadata-parametric forms in {!Act_c_mini}, these don't
    contain any accessors/constructors/traversals, but do group useful
    functionality that depends on knowing the metadata type. *)

(** {2 Subject labels} *)

module Label : sig
  type t = Metadata.t Act_c_mini.Label.t [@@deriving compare, equal, sexp]

  include Comparable.S with type t := t
  (** Labels can be compared; this becomes useful when maintaining label
      sets. *)
end

(** {2 Subject statements} *)

module Statement : sig
  type t = Metadata.t Act_c_mini.Statement.t [@@deriving sexp]

  module If : sig
    type t = Metadata.t Act_c_mini.Statement.If.t [@@deriving sexp]
  end

  module Loop : sig
    type t = Metadata.t Act_c_mini.Statement.While.t [@@deriving sexp]
  end
end

(** {2 Subject blocks} *)

module Block : sig
  type t = (Metadata.t, Statement.t) Act_c_mini.Block.t

  (** {3 Specialised constructors}

      For normal constructors, see {!Act_c_mini.Block}. *)

  val make_existing : ?statements:Statement.t list -> unit -> t
  (** [make_existing ?statements ()] makes a block, optionally containing
      the existing statements [statements], that is metadata-marked as
      existing before fuzzing. *)

  val make_generated : ?statements:Statement.t list -> unit -> t
  (** [make_generated ?statements ()] makes a block, optionally containing
      the existing statements [statements], that is metadata-marked as
      generated by the fuzzer. *)

  val make_dead_code : ?statements:Statement.t list -> unit -> t
  (** [make_generated ?statements ()] makes a block, optionally containing
      the existing statements [statements], that is metadata-marked as
      generated and dead-code-by-construction by the fuzzer. *)
end

(** {1 Fuzzable representation of a thread} *)
module Thread : sig
  type t =
    { decls: Act_c_mini.Initialiser.t Act_c_mini.Named.Alist.t
    ; stms: Statement.t list }
  [@@deriving sexp]
  (** Transparent type of fuzzable programs. *)

  (** {2 Constructors} *)

  val empty : t
  (** [empty] is the empty program. *)

  val make :
       ?decls:Act_c_mini.Initialiser.t Act_c_mini.Named.Alist.t
    -> ?stms:Statement.t list
    -> unit
    -> t
  (** [make ?decls ?stms ()] makes a thread with the given decls and
      statements (defaulting to empty). *)

  val of_function : unit Act_c_mini.Function.t -> t
  (** [of_litmus func] converts a mini-model C function [func] to the
      intermediate form used for fuzzing. *)

  val to_function :
       t
    -> vars:Var.Map.t
    -> id:int
    -> unit Act_c_mini.Function.t Act_c_mini.Named.t
  (** [to_function prog ~vars ~id] lifts a subject-program [prog] with ID
      [prog_id] back into a Litmus function, adding a parameter list
      generated from [vars] and erasing any metadata. *)

  val list_to_litmus :
    t list -> vars:Var.Map.t -> Act_c_mini.Litmus.Lang.Program.t list
  (** [list_to_litmus progs ~vars] lifts a list [progs] of subject-programs
      back into Litmus programs, adding parameter lists generated from
      [vars], and using the physical position of each program in the list to
      generate its thread ID. *)
end

(** Fuzzable representation of a litmus test. *)
module Test : sig
  type t = (Act_c_mini.Constant.t, Thread.t) Act_litmus.Test.Raw.t
  [@@deriving sexp]
  (** Transparent type of fuzzable litmus tests. *)

  val add_new_thread : t -> t
  (** [add_new_thread test] appends a new, empty thread onto [test]'s threads
      list, returning the resulting test. *)

  val of_litmus : Act_c_mini.Litmus.Test.t -> t
  (** [of_litmus test] converts a validated C litmus test [test] to the
      intermediate form used for fuzzing. *)

  val to_litmus : t -> vars:Var.Map.t -> Act_c_mini.Litmus.Test.t Or_error.t
  (** [to_litmus subject ~vars] tries to reconstitute a validated C litmus
      test from the subject [subject], using the variable map [vars] to
      reconstitute parameters. It may fail if the resulting litmus is
      invalid---generally, this signifies an internal error. *)

  (** {3 Availability queries} *)

  val has_statements : t -> bool
  (** [has_statements test] is true if, and only if, [test] contains at least
      one statement. *)

  val has_if_statements : t -> bool
  (** [has_statements test] is true if, and only if, [test] contains at least
      one if statement. *)

  val has_dead_code_blocks : t -> bool
  (** [has_dead_code_blocks test] is true if, and only if, [test] contains at
      least one dead code block. *)

  (** {3 Helpers for mutating tests} *)

  val add_var_to_init :
    t -> Act_common.C_id.t -> Act_c_mini.Constant.t -> t Or_error.t
  (** [add_var_to_init subject var initial_value] adds [var] to [subject]'s
      init block with the initial value [initial_value]. *)
end
