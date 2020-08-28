(* The Automagic Compiler Tormentor

   Copyright (c) 2018--2020 Matt Windsor and contributors

   ACT itself is licensed under the MIT License. See the LICENSE file in the
   project root for more information.

   ACT is based in part on code from the Herdtools7 project
   (https://github.com/herd/herdtools7) : see the LICENSE.herd file in the
   project root for more information. *)

(** Conversion of atomics from AST to FIR.

    In the AST, these atomics appear as function calls in both expression and
    statement position; in FIR, they have distinct representations. *)

open Base

(** {1 Names of functions} *)

val cmpxchg_name : string
(** [cmpxchg_name] is the name of the atomic compare-exchange function. *)

val fence_name : Act_fir.Atomic_fence.Mode.t -> string
(** [fence_name mode] is the name of the atomic fence function for mode
    [mode]. *)

val fetch_name : Act_fir.Op.Fetch.t -> string
(** [fetch_name] is the name of the atomic fetch-add function. *)

val load_name : string
(** [load_name] is the name of the atomic load function. *)

val store_name : string
(** [store_name] is the name of the atomic store function. *)

val xchg_name : string
(** [xchg_name] is the name of the atomic exchange function. *)

(** {1 Modeller helpers} *)

val fence_call_alist :
     (Ast.Expr.t list -> mode:Act_fir.Atomic_fence.Mode.t -> 'a)
  -> (Act_common.C_id.t, Ast.Expr.t list -> 'a) List.Assoc.t
(** [fence_call_alist f] builds an associative list mapping fence known-calls
    to modellers over their argument lists, using [f] to construct those
    modellers. *)

val fetch_call_alist :
     (Ast.Expr.t list -> op:Act_fir.Op.Fetch.t -> 'a)
  -> (Act_common.C_id.t, Ast.Expr.t list -> 'a) List.Assoc.t
(** [fetch_call_alist f] builds an associative list mapping fetch known-calls
    to modellers over their argument lists, using [f] to construct those
    modellers. *)

(** {1 Modellers} *)

val model_fence :
     Ast.Expr.t list
  -> mode:Act_fir.Atomic_fence.Mode.t
  -> Act_fir.Atomic_fence.t Or_error.t
(** [model_fence args ~mode] tries to convert an atomic-fence function call
    with arguments [args] and mode [mode] into an atomic fence. *)

val model_load : Ast.Expr.t list -> Act_fir.Atomic_load.t Or_error.t
(** [model_load args] tries to convert an atomic-load function call with
    arguments [args] into an atomic load. *)

(** {2 Modellers with recursive expressions} *)

val model_cmpxchg :
     Ast.Expr.t list
  -> expr:(Ast.Expr.t -> Act_fir.Expression.t Or_error.t)
  -> Act_fir.Expression.t Act_fir.Atomic_cmpxchg.t Or_error.t
(** [model_cmpxchg args ~expr] tries to convert an atomic compare-exchange
    function call with arguments [args] into an atomic compare-exchange,
    using [expr] to model inner expressions. *)

val model_fetch :
     Ast.Expr.t list
  -> op:Act_fir.Op.Fetch.t
  -> expr:(Ast.Expr.t -> Act_fir.Expression.t Or_error.t)
  -> Act_fir.Expression.t Act_fir.Atomic_fetch.t Or_error.t
(** [model_fetch args ~op ~expr] tries to convert an atomic fetch function
    call with arguments [args] and operation [op] into an atomic
    compare-exchange, using [expr] to model inner expressions. *)

val model_store :
     Ast.Expr.t list
  -> expr:(Ast.Expr.t -> Act_fir.Expression.t Or_error.t)
  -> Act_fir.Atomic_store.t Or_error.t
(** [model_store args ~expr] tries to convert an atomic store function call
    with arguments [args] into an atomic store, using [expr] to model inner
    expressions. *)

val model_xchg :
     Ast.Expr.t list
  -> expr:(Ast.Expr.t -> Act_fir.Expression.t Or_error.t)
  -> Act_fir.Expression.t Act_fir.Atomic_xchg.t Or_error.t
(** [model_xchg args ~expr] tries to convert an atomic exchange function call
    with arguments [args] into an atomic exchange, using [expr] to model
    inner expressions. *)