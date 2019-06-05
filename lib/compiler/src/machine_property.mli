(* This file is part of 'act'.

   Copyright (c) 2018 by Matt Windsor

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

(** Mini-language for querying machine specifications, suitable for use in
    [Blang]. *)

open Core_kernel
open Act_common

(** [t] is the opaque type of property queries. *)
type t [@@deriving sexp]

val id : Id.Property.t -> t
(** [id] constructs a query over a machine's ID. *)

val is_remote : t
(** [is_remote] constructs a query that asks if a machine is known to be
    remote. *)

val is_local : t
(** [is_local] constructs a query that asks if a machine is known to be
    local. *)

val eval : Machine_spec.With_id.t -> t -> bool
(** [eval R reference property] evaluates [property] over [reference], with
    respect to module [R]. *)

val eval_b : Machine_spec.With_id.t -> t Blang.t -> bool
(** [eval_b R reference expr] evaluates a [Blang] expression [expr] over
    [reference], with respect to module [R]. *)

include Property.S with type t := t