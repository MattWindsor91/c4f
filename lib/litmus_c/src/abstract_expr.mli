(* This file is part of c4f.

   Copyright (c) 2018-2021 C4 Project

   c4t itself is licensed under the MIT License. See the LICENSE file in the
   project root for more information.

   Parts of c4t are based on code from the Herdtools7 project
   (https://github.com/herd/herdtools7) : see the LICENSE.herd file in the
   project root for more information. *)

(** Abstracting expression ASTs into FIR.

    See {!Abstract} for the big picture. *)

open Base

val model : Ast.Expr.t -> C4f_fir.Expression.t Or_error.t
(** [model ast] tries to model a C expression AST as a FIR expression. *)
