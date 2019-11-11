(* The Automagic Compiler Tormentor

   Copyright (c) 2018--2019 Matt Windsor and contributors

   ACT itself is licensed under the MIT License. See the LICENSE file in the
   project root for more information.

   ACT is based in part on code from the Herdtools7 project
   (https://github.com/herd/herdtools7) : see the LICENSE.herd file in the
   project root for more information. *)

open Base
open Act_utils

(** [t] is an abstracted statement. *)
type t =
  | Directive of string
  | Instruction of Instruction.t
  | Blank
  | Label of string
  | Unknown

(** [Kind] is an enumeration over the high-level kinds of abstracted
    statement. *)
module Kind : sig
  type t = Directive | Instruction | Blank | Label | Unknown

  include Enum_types.S_table with type t := t

  include Enum_types.Extension_table with type t := t
end

(** [S_predicates] is the signature of any module that can access simple
    predicates over an abstract statement. *)
module type S_predicates = sig
  type t
  (** [t] is the type we're querying. *)

  include
    Instruction.S_predicates with type t := t
  (** We can apply instruction predicates to an abstract statement; they
      return [false] when the statement isn't an instruction. *)

  val is_directive : t -> bool
  (** [is_directive stm] decides whether [stm] appears to be an assembler
      directive. *)

  val is_instruction : t -> bool
  (** [is_instruction stm] tests whether [stm] is an instruction. *)

  val is_instruction_where : t -> f:(Instruction.t -> bool) -> bool
  (** [is_instruction_where stm ~f] tests whether [stm] is a label whose
      opcode and operands satisfy the predicate [f]. *)

  val is_label : t -> bool
  (** [is_label stm] decides whether [stm] appears to be an label. *)

  val is_label_where : t -> f:(string -> bool) -> bool
  (** [is_label_where stm ~f] tests whether [stm] is a label whose symbol
      satisfies the predicate [f]. *)

  val is_unused_label : t -> symbol_table:Symbol.Table.t -> bool
  (** [is_unused_label stm ~symbol_table] decides whether [stm] is a label
      whose symbol isn't registered as a jump destination in [symbol_table]. *)

  val is_jump_pair : t -> t -> bool
  (** [is_jump_pair x y] returns true if [x] is a jump instruction, [y] is a
      label, and [x] is jumping to [y]. *)

  val is_blank : t -> bool
  (** [is_blank stm] tests whether [stm] is a blank statement. *)

  val is_unknown : t -> bool
  (** [is_unknown stm] tests whether [stm] is an unknown statement. *)
end

(** [Inherit_predicates] generates a [S_predicates] by inheriting it from an
    optional component. Each predicate returns false when the component
    doesn't exist. *)
module Inherit_predicates
    (P : S_predicates)
    (I : Act_utils.Inherit_types.S_partial with type c := P.t) :
  S_predicates with type t := I.t

(** [Flag] is an enumeration of various statement observations. *)
module Flag : sig
  type t =
    [ `UnusedLabel (* A label that doesn't appear in any jumps *)
    | `StackManip
      (* A statement that only serves to manipulate the call stack *) ]
  [@@deriving sexp, enumerate]

  include Flag_enum.S with type t := t
end

(** [S_properties] is the signature of any module that can access properties
    (including predicates) of an abstract statement. *)
module type S_properties = sig
  type t
  (** [t] is the type we're querying. *)

  include
    S_predicates with type t := t
  (** Anything that can access properties can also access predicates. *)

  val exists :
       ?directive:(string -> bool)
    -> ?instruction:(Instruction.t -> bool)
    -> ?label:(Symbol.t -> bool)
    -> ?blank:bool
    -> ?unknown:bool
    -> t
    -> bool
  (** [exists ?directive ?instruction ?label ?blank ?unknown stm] returns
      [true] if [stm] is matched by any of the optional predicates. *)

  val iter :
       ?directive:(string -> unit)
    -> ?instruction:(Instruction.t -> unit)
    -> ?label:(Symbol.t -> unit)
    -> ?blank:(unit -> unit)
    -> ?unknown:(unit -> unit)
    -> t
    -> unit
  (** [iter ?directive ?instruction ?label ?blank ?unknown stm] executes any
      of the optional side-effecting functions that apply to [stm]. *)

  val flags : t -> Symbol.Table.t -> Set.M(Flag).t
  (** [flags x symbol_table] gets the statement flags for [x] given symbol
      table [symbol_table]. *)
end

(** [Inherit_properties] generates a [S_properties] by inheriting it from a
    component. *)
module Inherit_properties
    (P : S_properties)
    (I : Act_utils.Inherit_types.S with type c := P.t) :
  S_properties with type t := I.t

include
  S_properties with type t := t
(** This module contains [S_properties] directly. *)

include
  Node.S with type t := t and module Kind := Kind and module Flag := Flag
