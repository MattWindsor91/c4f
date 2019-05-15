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

(** Fuzzer: variable records and maps

    This module defines the types that the fuzzer uses to store information
    about variables. *)

open Core_kernel
open Act_utils

(** Type for storing variable values. *)
module Value : sig
  type t = Int of int
end

(** A variable 'known-value' record.

    These records are used to decide:

    {ul
     {- whether a generated variable has exactly one value throughout the
        lifetime of a litmus test (meaning we can depend on that value for
        generating other code);}
     {- whether that value is depended upon (meaning we can't use the
        variable as the target of a value-changing operation).}} *)
module Known_value : sig
  type t = {value: Value.t; has_dependencies: bool}
end

(** Variable records *)
module Record : sig
  type t

  (** {3 Constructors} *)

  val make_existing_global : Mini.Type.t -> t
  (** [make_existing_global ty] makes a variable record for a global
      variable of type [ty] that already existed in the program before
      mutation. *)

  val make_existing_local : C_identifier.t -> t
  (** [make_existing_local name] makes a variable record for a local
      variable with name [name] that already existed in the program before
      mutation. *)

  val make_generated_global : ?initial_value:Value.t -> Mini.Type.t -> t
  (** [make_generated_global ?initial_value ty] makes a variable record for
      a fuzzer-generated global variable of type [ty] and with initial value
      [value]. *)

  (** {3 Predicates} *)

  val is_global : t -> bool
  (** [is_global vr] returns whether [vr] is a global variable. *)

  val is_atomic : t -> bool
  (** [is_atomic vr] returns whether [vr] is an atomic variable. *)

  val was_generated : t -> bool
  (** [was_generated vr] returns whether [vr] was generated by the fuzzer. *)

  val has_dependencies : t -> bool
  (** [has_dependencies vr] returns true if [vr] has a known value that also
      has dependencies. *)

  val has_writes : t -> bool
  (** [has_writes vr] returns true if [vr] is known to have been written to. *)

  val has_known_value : t -> bool
  (** [has_known_value vr] returns whether [vr] has a known value. *)

  (** {3 Properties} *)

  val ty : t -> Mini.Type.t option
  (** Gets the type of the variable, if known. *)

  (** {3 Actions} *)

  val add_dependency : t -> t
  (** [add_dependency record] adds a dependency flag to the known-value
      field of [record].

      This should be done after involving [record] in any atomic actions
      that depend on its known value. *)

  val add_write : t -> t
  (** [add_write record] adds a write flag to the known-value field of
      [record].

      This should be done after involving [record] in any atomic actions
      that write to it, even if they don't change its known value. *)

  val erase_value : t -> t
  (** [erase_value record] erases the known-value field of [record].

      This should be done after involving [record] in any atomic actions
      that modify it. *)
end

(** Variable maps *)
module Map : sig
  (** Variable maps associate C identifiers with records. *)
  type t = Record.t C_identifier.Map.t

  (** {3 Constructors} *)

  val make_existing_var_map :
    Mini.Type.t C_identifier.Map.t -> C_identifier.Set.t -> t
  (** [make_existing_var_map globals locals] expands a set of known-existing
      C variable names to a var-record map where each name is registered as
      an existing variable.

      Global registrations override local ones, in the case of shadowing. *)

  (** {3 Queries} *)

  val env_satisfying_all :
       t
    -> predicates:(Record.t -> bool) list
    -> Mini.Type.t C_identifier.Map.t
  (** [env_satisfying_all map ~predicates] returns a typing environment for
      all variables in [map] with known types, and for which all predicates
      in [predicates] are true. *)

  val env_module_satisfying_all :
    t -> predicates:(Record.t -> bool) list -> (module Mini_env.S)
  (** [env_module_satisfying_all map ~predicates] behaves like
      {{!env_satisfying_all} env_satisfying_all}, but wraps the result in a
      first-class module. *)

  val satisfying_all :
    t -> predicates:(Record.t -> bool) list -> C_identifier.t list
  (** [satisfying_all map ~predicates] returns a list of all variables in
      [map] for which all predicates in [predicates] are true. *)

  val exists_satisfying_all :
    t -> predicates:(Record.t -> bool) list -> bool
  (** [exists_satisfying_all map ~predicates] returns whether there exists
      at least one variable in [map] for which all predicates in
      [predicates] are true. *)

  (** {3 Actions} *)

  val register_global :
    ?initial_value:Value.t -> t -> C_identifier.t -> Mini.Type.t -> t
  (** [register_global ?initial_value map var ty] registers a generated
      global variable with name [var], type [ty], and optional known initial
      value [initial_value] in [map], returning the resulting new map. *)

  val gen_fresh_var : t -> C_identifier.t Quickcheck.Generator.t
  (** [gen_fresh_var map] generates random C identifiers that don't shadow
      existing variables in [map]. *)

  val add_dependency : t -> var:C_identifier.t -> t
  (** [add_dependency map ~var] adds a dependency flag in [map] for [var],
      returning the resulting new map.

      This should be done after involving [var] in any atomic actions that
      depend on its known value. *)

  val add_write : t -> var:C_identifier.t -> t
  (** [add_write map ~var] adds a write flag in [map] for [var], returning
      the resulting new map.

      This should be done after involving [var] in any atomic actions that
      write to it, even if they don't modify its value. *)

  val erase_value : t -> var:C_identifier.t -> t Or_error.t
  (** [erase_value map ~var] erases the known-value field for any mapping
      for [var] in [map], returning the resulting new map.

      [erase_value] fails if [var] is mapped to a record whose known value
      field is present and has dependencies. This is a precaution to flag up
      unsafe attempts to alter [var]'s value.

      This should be done after involving [var] in any atomic actions that
      modify it. *)
end
