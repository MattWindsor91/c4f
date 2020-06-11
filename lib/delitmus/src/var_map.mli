(* The Automagic Compiler Tormentor

   Copyright (c) 2018--2019 Matt Windsor and contributors

   ACT itself is licensed under the MIT License. See the LICENSE file in the
   project root for more information.

   ACT is based in part on code from the Herdtools7 project
   (https://github.com/herd/herdtools7) : see the LICENSE.herd file in the
   project root for more information. *)

(** Post-delitmus variable maps.

    These maps primarily associate Litmus IDs with the global symbols into
    which the delitmusifier has flattened them. *)

open Base

(** {1 Mapping information}

    {!Mapping} contains an enumeration of ways in which a variable in a
    Litmus test maps to a variable in the delitmusified form. *)

module Mapping : sig
  (** Type of mappings. *)
  type t =
    | Global  (** Mapped to a global variable. *)
    | Param of int
        (** Mapped to a parameter on each thread function, with the given
            index. *)
  [@@deriving yojson, equal]
end

(** {1 Records} *)

module Record : sig
  type t [@@deriving yojson, equal]

  val make :
       c_type:Act_fir.Type.t
    -> c_id:Act_common.C_id.t
    -> mapped_to:Mapping.t
    -> t
  (** [make ~c_type ~c_id ~mapped_to] constructs a variable map record for a
      variable with mapped C name [c_id] and type [c_id], and delitmus
      mapping information supplied by [mapped_to]. *)

  (** {2 Accessors} *)

  val c_type : t -> Act_fir.Type.t
  (** [c_type r] gets the C type of [r]. *)

  val c_id : t -> Act_common.C_id.t
  (** [c_id r] gets the delitmusified C variable name of [r]. *)

  val mapped_to : t -> Mapping.t
  (** [mapped_to_global r] gets how [r]'s variable maps into the
      delitmusified version of the test. *)

  val mapped_to_global : t -> bool
  (** [mapped_to_global r] gets whether [r]'s variable has been mapped into
      the global scope. *)

  val mapped_to_param : t -> bool
  (** [mapped_to_param r] gets whether [r]'s variable has been mapped into a
      parameter. *)
end

(** Delitmus variable maps are a specific case of scoped map. *)
type t = Record.t Act_common.Scoped_map.t [@@deriving equal]

(** {1 Projections specific to delitmus variable maps} *)

val param_mapped_vars : t -> (Act_common.Litmus_id.t, Record.t) List.Assoc.t
(** [param_mapped_vars vm] extracts an associative list of variables from
    [vm] that are intended to be mapped to parameters. The list is sorted by
    parameter index, not by litmus ID. *)

val globally_mapped_vars :
  t -> (Act_common.Litmus_id.t, Record.t) List.Assoc.t
(** [globally_mapped_vars vm] extracts an associative list of variables from
    [vm] that are intended to be mapped to global variables. The list is
    sorted by litmus ID. *)

val global_c_variables : t -> Set.M(Act_common.C_id).t
(** [global_c_variables map] gets the set of global C variables generated by
    the delitmusifier over [map]. *)

val lookup_and_require_global :
  t -> id:Act_common.Litmus_id.t -> Act_common.C_id.t Or_error.t
(** [lookup_and_require_global map ~id] looks up the Litmus ID [id] in the
    var map. It returns [x] if [id] was mapped to a global C variable [id] in
    [map], or an error otherwise (ie, [id] was not mapped to a global C
    variable, or not seen at all). *)

val lookup_and_require_param :
  t -> id:Act_common.Litmus_id.t -> Act_common.C_id.t Or_error.t
(** [lookup_and_require_param map ~id] behaves as
    {!lookup_and_require_global}, but instead requires that [id] was mapped
    to a function parameter. *)

(** {2 Interface implementations} *)

(** A var map can be serialised to, and deserialised from, (Yo)JSON. *)
include Plumbing.Jsonable_types.S with type t := t
