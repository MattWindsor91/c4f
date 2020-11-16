(* The Automagic Compiler Tormentor

   Copyright (c) 2018, 2019, 2020 Matt Windsor and contributors

   ACT itself is licensed under the MIT License. See the LICENSE file in the
   project root for more information.

   ACT is based in part on code from the Herdtools7 project
   (https://github.com/herd/herdtools7) : see the LICENSE.herd file in the
   project root for more information. *)

(** Utilities for the various expression generators. *)

open Import

val has_ints : Fir.Env.t -> is_atomic:bool -> bool
(** [has_ints env ~is_atomic] is sugar for testing whether [env] has integer
    variables with atomicity [is_atomic]. *)

val has_bools : Fir.Env.t -> is_atomic:bool -> bool
(** [has_bools env ~is_atomic] is sugar for testing whether [env] has Boolean
    variables with atomicity [is_atomic]. *)

val with_record :
     'a Q.Generator.t
  -> to_var:('a -> Act_common.C_id.t)
  -> env:Fir.Env.t
  -> ('a * Fir.Env.Record.t) Q.Generator.t
(** [with_record gen ~to_var ~env] attaches to values generated with [gen] a
    variable record found through [to_var] and [env]. *)

val lift_loadlike :
     'a Q.Generator.t
  -> to_expr:('a -> Fir.Expression.t)
  -> to_var:('a -> Common.C_id.t)
  -> env:Fir.Env.t
  -> (Fir.Expression.t * Fir.Env.Record.t) Q.Generator.t
(** [lift_loadlike gen ~to_expr ~to_var ~env] lifts a loadlike expression
    generator [gen] to one that returns an expression through [to_expr] and a
    variable record through [to_var] and [env]. *)
