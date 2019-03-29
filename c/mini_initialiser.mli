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

(** Mini-model: initialisers. *)

(** Opaque type of initialisers. *)
type t [@@deriving sexp, eq, quickcheck]

(** {3 Constructors} *)

val make : ty:Mini_type.t -> ?value:Ast_basic.Constant.t -> unit -> t
(** [make ~ty ?value ()] makes an initialiser with type [ty] and optional
    initialised value [value]. *)

(** {3 Accessors} *)

val ty : t -> Mini_type.t
(** [ty init] gets the type of [init]. *)

val value : t -> Ast_basic.Constant.t option
(** [value init] gets the initialised value of [init], if it has one. *)

(** Allows using the type of named initialiser in certain functors. *)
module Named : Mini_intf.S_named with type elt := t
