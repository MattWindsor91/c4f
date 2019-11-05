(* The Automagic Compiler Tormentor

   Copyright (c) 2018--2019 Matt Windsor and contributors

   ACT itself is licensed under the MIT License. See the LICENSE file in the
   project root for more information.

   ACT is based in part on code from the Herdtools7 project
   (https://github.com/herd/herdtools7) : see the LICENSE.herd file in the
   project root for more information. *)

(** [Blang]-based property interface for filtering compilers. *)

type t [@@deriving sexp]
(** [t] is the opaque type of property queries. *)

(** {1 Constructors} *)

val id : Act_common.Id.Property.t -> t
(** [id] constructs a query over a backend's ID. *)

val style : Act_common.Id.Property.t -> t
(** [has_style style] constructs a query over a backend's style ID. *)

(** {1 Interface implementations} *)

include
  Act_common.Property_types.S_bool
    with type t := t
     and type target := Spec.With_id.t
