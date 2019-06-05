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

(** Signatures used in the plumbing module. *)

open Stdio
open Base

(** Types and values common to both the basic and full filter signatures. *)
module type Common = sig
  (** Type of any auxiliary state consumed by this filter. *)
  type aux_i

  (** Type of any auxiliary state built by this filter. *)
  type aux_o

  val name : string
  (** [name] is the name of this filter. *)

  val tmp_file_ext : aux_i Filter_context.t -> string
  (** [tmp_file_ext ctx] gives the extension that any temporary files output
      by this filter should have, given the context [ctx]. *)
end

module type Basic = sig
  include Common

  val run :
       aux_i Filter_context.t
    -> In_channel.t
    -> Out_channel.t
    -> aux_o Or_error.t
end

(** Input signature for filters that require physical files in input
    position. *)
module type Basic_in_file_only = sig
  include Common

  val run :
    aux_i Filter_context.t -> Fpath.t -> Out_channel.t -> aux_o Or_error.t
end

(** Input signature for filters that require physical files in both input
    and output position. *)
module type Basic_files_only = sig
  include Common

  val run :
       aux_i Filter_context.t
    -> infile:Fpath.t
    -> outfile:Fpath.t
    -> aux_o Or_error.t
end

module type S = sig
  include Common

  val run : aux_i -> Input.t -> Output.t -> aux_o Or_error.t
  (** [run aux source sink] runs this filter on [source], outputs to [sink],
      reads and returns any auxiliary state on success. *)
end

(** Signature of inputs needed to adapt a filter. *)
module type Basic_adapt = sig
  (** The original filter. *)
  module Original : S

  (** The new input type. *)
  type aux_i

  (** The new output type. *)
  type aux_o

  val adapt_i : aux_i -> Original.aux_i Or_error.t
  (** [adapt_i aux] tries to adapt the new input type to the old one. *)

  val adapt_o : Original.aux_o -> aux_o Or_error.t
  (** [adapt_i aux] tries to adapt the old output type to the new one. *)
end

(** Basic signature for building filters from external programs on top of a
    [Runner]. *)
module type Basic_on_runner = sig
  include Common with type aux_o := unit

  (** The runner to use to run the program. *)
  module Runner : Runner_types.S

  val prog : aux_i -> string
  (** [prog aux] gets the program to run, given the auxiliary input [aux]. *)

  val argv : aux_i -> string -> string list
  (** [argv aux file] gets the argument vector to supply, given the
      auxiliary input [aux] and input file [file]. *)
end