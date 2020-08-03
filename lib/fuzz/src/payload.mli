(* The Automagic Compiler Tormentor

   Copyright (c) 2018--2019 Matt Windsor and contributors

   ACT itself is licensed under the MIT License. See the LICENSE file in the
   project root for more information.

   ACT is based in part on code from the Herdtools7 project
   (https://github.com/herd/herdtools7) : see the LICENSE.herd file in the
   project root for more information. *)

(** Stock payloads, helpers for building payloads, and so on.

    See {!Action_types.S_payload} for the shape of an action payload. *)

open Base

(** Type shorthand for functions that statefully generate values. *)
type 'a stateful_gen =
     Subject.Test.t
  -> random:Splittable_random.State.t
  -> param_map:Param_map.t
  -> 'a State.Monad.t

(** {1 Helpers for building action payloads} *)

module Helpers : sig
  val lift_quickcheck :
       'a Base_quickcheck.Generator.t
    -> random:Splittable_random.State.t
    -> 'a State.Monad.t
  (** [lift_quickcheck gen ~random] lifts a Quickcheck-style generator [gen]
      into a state-monad action taking a random number generator [random] and
      outputting the randomly generated value. *)

  val lift_quickcheck_opt :
       'a Opt_gen.t
    -> random:Splittable_random.State.t
    -> action_id:Act_common.Id.t
    -> 'a State.Monad.t
  (** [lift_quickcheck_opt gen_opt ~random ~action_id] behaves as
      {!lift_quickcheck} if [gen_opt] is [Ok gen], and lifts the error inside
      the state monad if not. The caller must provide the ID of the action
      whose payload is being generated as [action_id]. *)

  val gen_path :
       Subject.Test.t
    -> random:Splittable_random.State.t
    -> action_id:Act_common.Id.t
    -> filter:Path_filter.t State.Monad.t
    -> kind:Path_kind.t
    -> Path.Test.t State.Monad.t
  (** [gen_path subject ~random ~action_id ~filter ~kind] is a a monadic
      action that generates a path of kind [kind] and with filter [filter]
      for an action payload. *)
end

(** {1 Stock payloads and functors for building them} *)

(** Dummy payload module for actions that take no payload. *)
module None : Action_types.S_payload with type t = unit

(** Adapts payload generators that don't depend on the state of the program. *)
module Pure (Basic : sig
  type t [@@deriving sexp]

  val quickcheck_generator : t Base_quickcheck.Generator.t
end) : Action_types.S_payload with type t = Basic.t

(** Type of results of a [Stm_insert] application. *)
module Insertion : sig
  (** Opaque type of insertion payloads. *)
  type 'a t [@@deriving sexp]

  val make : to_insert:'a -> where:Path.Test.t -> 'a t
  (** [make ~to_insert ~where] makes a payload that expresses the desire to
      insert [to_insert] using path [where]. *)

  val to_insert : 'a t -> 'a
  (** [to_insert x] gets the insertion candidate of [x]. *)

  val where : _ t -> Path.Test.t
  (** [where x] gets the program path to which [x] is inserting. *)

  (** Constructs a payload for inserting a statement. *)
  module Make (To_insert : sig
    type t [@@deriving sexp]

    val name : Act_common.Id.t
    (** [name] should be the approximate ID of the action. *)

    val path_filter : Path_filter.t State.Monad.t
    (** [path_filter] is a stateful action that generates a path filter. *)

    val gen : Path.Test.t -> t stateful_gen
    (** [gen where] generates the inner payload given the generated path
        [where]. *)
  end) : Action_types.S_payload with type t = To_insert.t t
end

(** {2 Surround} *)

(* Payload for actions that surround a statement span with a flow block or if
   statement that requires a conditional.

   The payload for any surround action contains two elements:

   - the expression to insert into the condition of the if statement; - the
   path to the statements to remove, pass through the if statement block
   generators, and replace with the statement. *)
module Cond_surround : sig
  (** Opaque type of payloads. *)
  type t

  (** {3 Constructors} *)

  val make : cond:Act_fir.Expression.t -> where:Path.Test.t -> t
  (** [make ~cond ~where] makes a payload given a specific condition
      expression [cond] and statement-list selecting path [where]. *)

  (** {3 Accessors} *)

  val cond : t -> Act_fir.Expression.t
  (** [cond payload] retrieves the generated condition inside [payload]. *)

  val where : t -> Path.Test.t
  (** [where payload] retrieves the generated path inside [payload]. *)

  val apply :
       ?filter:Path_filter.t
    -> t
    -> test:Subject.Test.t
    -> f:
         (   Act_fir.Expression.t
          -> Subject.Statement.t list
          -> Subject.Statement.t)
    -> Subject.Test.t State.Monad.t
  (** [apply ?filter payload ~test ~f] lifts a surrounding function [f] over
      a payload [payload], supplying the test [test] to transform, and
      lifting the computation into the fuzzer state monad. If [filter] is
      given, the path in [payload] will be checked for compliance with it. *)

  (** {3 Using as a payload module} *)

  (** [Make] builds a fully-functional payload module with the surround
      payload and a generator that uses the given conditional generator. *)
  module Make (Basic : sig
    val name : Act_common.Id.t
    (** [name] should be the approximate ID of the action whose payload is
        being defined. *)

    val cond_gen :
      Act_fir.Env.t -> Act_fir.Expression.t Base_quickcheck.Generator.t
    (** [cond_gen env] should, given an environment [env] capturing the
        variables in scope at the point where the if statement is appearing,
        return a Quickcheck generator generating expressions over those
        variables. *)

    val path_filter : Path_filter.t State.Monad.t
    (** [path_filter] should apply any additional path filter conditions
        needed for the action; for example, requiring that the scooped
        statement list must have no labels. *)
  end) : Action_types.S_payload with type t = t
end
