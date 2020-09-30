(* The Automagic Compiler Tormentor

   Copyright (c) 2018, 2019, 2020 Matt Windsor and contributors

   ACT itself is licensed under the MIT License. See the LICENSE file in the
   project root for more information.

   ACT is based in part on code from the Herdtools7 project
   (https://github.com/herd/herdtools7) : see the LICENSE.herd file in the
   project root for more information. *)

(** Fuzzer: high-level actions *)

open Base
open Import

(** {1 Types} *)

(** An action as a first-class module. *)
type t = (module Action_types.S)

(** {2 Actions with default weights}

    This module concerns actions bundled with their default weight. This is
    the way in which actions are stored natively in the action table; we
    don't keep default weights in the actual action modules to avoid them
    being scattered over various files. *)
module With_default_weight : sig
  (** Opaque type of actions-with-default-weight. *)
  type t

  val make : action:(module Action_types.S) -> default_weight:int -> t
  (** [make ~action ~default_weight] constructs an action-with-default-weight
      from its action module [action] and default weight [default_weight]. *)

  val ( @-> ) : (module Action_types.S) -> int -> t
  (** [action @-> default_weight] is an infix operator version of [make]. *)

  (** {3 Accessors} *)

  val action : t -> (module Action_types.S)
  (** [action a] gets [a]'s action module. *)

  val default_weight : t -> int
  (** [default_weight a] gets [a]'s default weight. *)

  val name : t -> Common.Id.t
  (** [name a] is shorthand for [A.name], where [A] is [action a]. *)
end

(** {1 Summaries of actions}

    To build these summaries, see {!Pool.summarise} below. *)

(** A summary of the weight assigned to an action in an action pool. *)
module Adjusted_weight : sig
  (** Type of adjusted weight summaries. *)
  type t =
    | Not_adjusted of int  (** The user hasn't overridden this weight. *)
    | Adjusted of {original: int; actual: int}
        (** The weight has changed from [original] to [actual]. *)

  (** Adjusted weights may be pretty-printed. *)
  include Pretty_printer.S with type t := t
end

(** A summary of a fuzzer action after weight adjustment. *)
module Summary : sig
  (** Opaque type of summaries. *)
  type t

  val make : weight:Adjusted_weight.t -> readme:string -> t
  (** [make ~weight ~summary] makes a fuzzer action summary. *)

  val of_action : ?user_weight:int -> With_default_weight.t -> t
  (** [of_action ?user_weight ~action] makes a fuzzer action summary using an
      action [action] and the given user weighting [user_weight]. *)

  val weight : t -> Adjusted_weight.t
  (** [weight summary] gets the final 'adjusted' weight of the action
      described by [summary]. *)

  val readme : t -> string
  (** [readme summary] gets the README of the action described by [summary]. *)

  (** Summaries may be pretty-printed. *)
  include Pretty_printer.S with type t := t

  val pp_map : t Map.M(Common.Id).t Fmt.t
  (** [pp_map f map] pretty-prints a map of summaries [map] on formatter [f]. *)

  val pp_map_terse : t Map.M(Common.Id).t Fmt.t
  (** [pp_map_terse f map] is like {!pp_map}, but only prints names and
      weights. *)
end

(** {1 Helpers for building actions} *)

(** Makes a basic logging function for an action. *)
module Make_log (B : sig
  val name : Common.Id.t
end) : sig
  val log : Common.Output.t -> ('a, Formatter.t, unit) format -> 'a
end

(** Makes a surrounding action. *)
module Make_surround (Basic : Action_types.Basic_surround) :
  Action_types.S with type Payload.t = Basic.Payload.t Payload_impl.Pathed.t

(** An action that does absolutely nothing. *)
module Nop : Action_types.S with type Payload.t = unit
