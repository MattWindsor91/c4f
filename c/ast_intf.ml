(* This file is part of 'act'.

   Copyright (c) 2018 by Matt Windsor (parts (c) 2010-2018 Institut
   National de Recherche en Informatique et en Automatique, Jade
   Alglave, and Luc Maranget)

   Permission is hereby granted, free of charge, to any person
   obtaining a copy of this software and associated documentation
   files (the "Software"), to deal in the Software without
   restriction, including without limitation the rights to use, copy,
   modify, merge, publish, distribute, sublicense, and/or sell copies
   of the Software, and to permit persons to whom the Software is
   furnished to do so, subject to the following conditions:

   The above copyright notice and this permission notice shall be
   included in all copies or substantial portions of the Software.

   THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
   EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
   MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
   NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS
   BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN
   ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN
   CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
   SOFTWARE.

   This file derives from the Herd7 project
   (https://github.com/herd/herdtools7); its original attribution and
   copyright notice follow. *)


(****************************************************************************)
(*                           the diy toolsuite                              *)
(*                                                                          *)
(* Jade Alglave, University College London, UK.                             *)
(* Luc Maranget, INRIA Paris-Rocquencourt, France.                          *)
(*                                                                          *)
(* Copyright 2010-present Institut National de Recherche en Informatique et *)
(* en Automatique and the authors. All rights reserved.                     *)
(*                                                                          *)
(* This software is governed by the CeCILL-B license under French law and   *)
(* abiding by the rules of distribution of free software. You can use,      *)
(* modify and/ or redistribute the software under the terms of the CeCILL-B *)
(* license as circulated by CEA, CNRS and INRIA at the following URL        *)
(* "http://www.cecill.info". We also give a copy in LICENSE.txt.            *)
(****************************************************************************)

open Base
open Ast_basic

(** {2 Signatures of specific nodes} *)

(** {3 Signatures shared between multiple nodes} *)

(** Signature of general declaration nodes. *)
module type S_g_decl = sig
  type qual (** Type of qualifiers *)
  type decl (** Type of declarators *)

  type t =
    { qualifiers : qual list
    ; declarator : decl
    }
  [@@deriving sexp]
  ;;

  val pp : t Fmt.t
end

(** Signature of general composite (enum, struct, union) specifiers. *)
module type S_composite_spec = sig
  type kind (** Type of kind of composite spec (eg. 'enum') *)
  type decl (** Type of internal declarations *)

  type t =
    | Literal of
        { kind     : kind
        ; name_opt : Identifier.t option
        ; decls    : decl list
        }
    | Named of kind * string
  [@@deriving sexp]

  include Ast_node with type t := t
end

(** {3 Declarators} *)

(** Signature of direct declarators. *)
module type S_direct_declarator = sig
  type dec  (** Type of declarators *)
  type par  (** Type of parameters *)
  type expr (** Type of expressions *)

  type t =
    | Id of Identifier.t
    | Bracket of dec
    | Array of (t, expr option) Array.t
    | Fun_decl of t * par
    | Fun_call of t * Identifier.t list
  [@@deriving sexp]
  ;;

  include Ast_node_with_identifier with type t := t
end

(** Signature of declarators. *)
module type S_declarator = sig
  type ddec (** Type of direct declarators *)

  type t =
    { pointer : Pointer.t option
    ; direct  : ddec
    }
  [@@deriving sexp]
  ;;

  include Ast_node_with_identifier with type t := t
end

(** Signature of direct abstract declarators. *)
module type S_direct_abs_declarator = sig
  type dec  (** Type of abstract declarators *)
  type par  (** Type of parameters *)
  type expr (** Type of expressions *)

  type t =
    | Bracket of dec
    | Array of (t option, expr option) Array.t
    | Fun_decl of t option * par option
  [@@deriving sexp]
  ;;

  include Ast_node with type t := t
end

(** Signature of abstract declarators. *)
module type S_abs_declarator = sig
  type ddec (** Type of direct abstract declarators. *)

  type t =
    | Pointer of Pointer.t
    | Direct of Pointer.t option * ddec
  [@@deriving sexp]
  ;;

  include Ast_node with type t := t
end

(** Signature of struct declarators. *)
module type S_struct_declarator = sig
  type dec  (** Type of declarations *)
  type expr (** Type of expressions *)

  type t =
    | Regular of dec
    | Bitfield of dec option * expr
  [@@deriving sexp]
  ;;

  include Ast_node with type t := t
end

(* {3 Other} *)


(** Signature of expression nodes. *)
module type S_expr = sig
  module Ty : Ast_node  (** Type of type names. *)

  type t =
    | Prefix      of Operators.Pre.t * t
    | Postfix     of t * Operators.Post.t
    | Binary      of t * Operators.Bin.t * t
    | Ternary     of { cond   : t
                     ; t_expr : t
                     ; f_expr : t
                     }
    | Cast        of Ty.t * t
    | Call        of { func : t; arguments : t list}
    | Subscript   of (t, t) Array.t
    | Field       of { value  : t
                     ; field  : Identifier.t
                     ; access : [ `Direct (* . *) | `Deref (* -> *) ]
                     }
    | Sizeof_type of Ty.t
    | Identifier  of Identifier.t
    | String      of String.t
    | Constant    of Constant.t
    | Brackets    of t
  [@@deriving sexp]
  ;;

  include Ast_node with type t := t
end

(** Signature of labels *)
module type S_label = sig
  type expr (** Type of expressions used in case labels *)

  type t =
    | Normal of Identifier.t
    | Case   of expr
    | Default
  [@@deriving sexp]
  ;;

  include Ast_node with type t := t
end

(** Signature of type specifiers *)
module type S_type_spec = sig
  type su (** Type of struct-or-union specifiers *)
  type en (** Type of enum specifiers *)

  type t =
    [ Prim_type.t
    | `Struct_or_union of su
    | `Enum of en
    | `Defined_type of Identifier.t
    ]
  [@@deriving sexp]
  ;;

  include Ast_node with type t := t
end

(** Signature of parameter type lists *)
module type S_param_type_list = sig
  type pdecl (** Type of parameter declarations *)

  type t =
    { params : pdecl list
    ; style  : [`Normal | `Variadic]
    }
  [@@deriving sexp]
  ;;

  include Ast_node with type t := t
end
