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

open Stdio
open Base

(** Collection of all the context used by filters to make internal
    decisions. *)
type 'aux ctx = {aux: 'aux; src: Io.In_source.t; sink: Io.Out_sink.t}

(** Type used when forwarding the output of the first item in a chained
    filter to the input of a second. *)
type 'o chain_output = [`Checking_ahead | `Skipped | `Ran of 'o]

(** Types and values common to both the basic and full filter signatures. *)
module type Common = sig
  (** Type of any auxiliary state consumed by this filter. *)
  type aux_i

  (** Type of any auxiliary state built by this filter. *)
  type aux_o

  val name : string
  (** [name] is the name of this filter. *)

  val tmp_file_ext : aux_i ctx -> string
  (** [tmp_file_ext ctx] gives the extension that any temporary files output
      by this filter should have, given the context [ctx]. *)
end

module type Basic = sig
  include Common

  val run : aux_i ctx -> In_channel.t -> Out_channel.t -> aux_o Or_error.t
end

(** Input signature for filters that require physical files in input
    position. *)
module type Basic_in_file_only = sig
  include Common

  val run : aux_i ctx -> Fpath.t -> Out_channel.t -> aux_o Or_error.t
end

(** Input signature for filters that require physical files in both input
    and output position. *)
module type Basic_files_only = sig
  include Common

  val run :
    aux_i ctx -> infile:Fpath.t -> outfile:Fpath.t -> aux_o Or_error.t
end

module type S = sig
  include Common

  val run : aux_i -> Io.In_source.t -> Io.Out_sink.t -> aux_o Or_error.t
  (** [run aux source sink] runs this filter on [source], outputs to [sink],
      reads and returns any auxiliary state on success. *)

  val run_from_fpaths :
       aux_i
    -> infile:Fpath.t option
    -> outfile:Fpath.t option
    -> aux_o Or_error.t
  (** [run_from_fpaths aux ~infile ~outfile] runs this filter on [infile]
      (if [None], use stdin), outputs to [outfile] (if [None], use stdout),
      and returns any auxiliary state on success. *)

  val run_from_string_paths :
       aux_i
    -> infile:string option
    -> outfile:string option
    -> aux_o Or_error.t
  (** [run_from_string_paths aux ~infile ~outfile] runs this filter on
      [infile] (if [None], use stdin), outputs to [outfile] (if [None], use
      stdout), and returns any auxiliary state on success. *)
end

(** Basic signature of inputs needed to build a chain. *)
module type Basic_chain = sig
  (** The first filter. *)
  module First : S

  (** The second filter. *)
  module Second : S

  (** Combined auxiliary input. *)
  type aux_i
end

(** Signature of inputs needed to build an unconditional chain. *)
module type Basic_chain_unconditional = sig
  include Basic_chain

  val first_input : aux_i -> First.aux_i
  (** [first_input in] should extract the input for the first chained filter
      from [in]. *)

  val second_input : aux_i -> First.aux_o chain_output -> Second.aux_i
  (** [second_input in first_out] should extract the input for the second
      chained filter from [in] and the output [first_out] from the first
      filter. [first_out] may be missing; this usually occurs when the
      second input is needed before the first filter has run. *)
end

(** Signature of inputs needed to build a conditional chain. *)
module type Basic_chain_conditional = sig
  include Basic_chain

  (** Auxiliary input used when not chaining. *)
  type aux_i_single

  val select :
       aux_i ctx
    -> [ `Both of First.aux_i * (First.aux_o chain_output -> Second.aux_i)
       | `One of aux_i_single ]
  (** [select ctx] should return [`Both] when the optional filter should be
      run (which filter this is depends on the functor). *)
end

(** Signature of inputs needed to build a conditional chain with the first
    filter being conditional. *)
module type Basic_chain_conditional_first = sig
  (** The first filter. *)
  module First : S

  (** The second filter. *)
  module Second : S

  include
    Basic_chain_conditional
    with module First := First
     and module Second := Second
     and type aux_i_single := First.aux_o chain_output -> Second.aux_i
end

(** Signature of inputs needed to build a conditional chain with the second
    filter being conditional. *)
module type Basic_chain_conditional_second = sig
  (** The first filter. *)
  module First : S

  include
    Basic_chain_conditional
    with module First := First
     and type aux_i_single := First.aux_i
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
  module Runner : Runner.S

  val prog : aux_i -> string
  (** [prog aux] gets the program to run, given the auxiliary input [aux]. *)

  val argv : aux_i -> string -> string list
  (** [argv aux file] gets the argument vector to supply, given the
      auxiliary input [aux] and input file [file]. *)
end
