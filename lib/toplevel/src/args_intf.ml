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

(** Module types used in {{!Args} Args}. *)

open Core

(** Signature of modules describing argument bundles that include the
    standard arguments. *)
module type S_standard = sig
  type t
  (** A record collecting the standard argument values. *)

  type s
  (** The standard arguments record type, used by [as_standard_args]. *)

  val as_standard_args : t -> s
  (** [as_standard_args args] restricts [args] to the 'standard arguments'
      type; this is useful mainly for command lifting. *)

  val is_verbose : t -> bool
  (** [is_verbose t] gets whether, according to [t], verbose mode is
      switched on. *)

  val are_warnings_enabled : t -> bool
  (** [are_warnings_enabled t] gets whether, according to [t], warnings are
      switched on. *)

  val colour : t -> Fmt.style_renderer option
  (** [colour t] gets the TTY colouring mode, if any, according to [t]. *)

  val config_file : t -> string
  (** [config_file t] gets the configuration file according to [t]. *)

  val get : t Command.Param.t
  (** [get] is a [Command.Param.t] that describes how to get the standard
      arguments at the command line. *)
end

(** Signature of modules describing argument bundles that include the
    standard and standard-file arguments. *)
module type S_standard_with_files = sig
  type t
  (** Opaque type of processed argument records. *)

  include S_standard with type t := t

  (** {3 Retrieving input and output files} *)

  val infile_raw : t -> string option
  (** [infile_raw args] gets the input file as provided as an argument, if
      one indeed was. *)

  val infile_fpath : t -> Fpath.t option Or_error.t
  (** [infile_fpath args] behaves as {{!infile_raw} infile_raw}, but tries
      to parse any given input file as an Fpath. This may fail if the path
      is ill-formed. *)

  val infile_source : t -> Plumbing.Input.t Or_error.t
  (** [infile_source args] behaves as {{!infile_raw} infile_raw}, but tries
      to convert the result to an {{!Io.In_source.t} In_source.t}. This may
      fail if the path is ill-formed. *)

  val outfile_raw : t -> string option
  (** [outfile_raw args] gets the output file as provided as an argument, if
      one indeed was. *)

  val outfile_fpath : t -> Fpath.t option Or_error.t
  (** [outfile_fpath args] behaves as {{!outfile_raw} outfile_raw}, but
      tries to parse any given output file as an Fpath. This may fail if the
      path is ill-formed. *)

  val outfile_sink : t -> Plumbing.Output.t Or_error.t
  (** [outfile_sink args] behaves as {{!outfile_raw} outfile_raw}, but tries
      to convert the result to an {{!Io.Out_sink.t} Out_sink.t}. This may
      fail if the path is ill-formed. *)

  val run_filter :
       (module Plumbing.Filter_types.S
          with type aux_i = 'i
           and type aux_o = 'o)
    -> t
    -> aux_in:'i
    -> 'o Or_error.t
  (** [run_filter f args ~aux_in] runs the filter [f] with the file input
      and output arguments specified in [args], and the auxiliary input
      [aux_in], returning the auxiliary output or errors arising. *)

  val run_filter_with_aux_out :
       ?aux_out_filename:string
    -> (module Plumbing.Filter_types.S
          with type aux_i = 'i
           and type aux_o = 'o)
    -> t
    -> aux_in:'i
    -> aux_out_f:('o -> Stdio.Out_channel.t -> unit Or_error.t)
    -> unit Or_error.t
  (** [run_filter_with_aux_out ?aux_out_filename f args ~aux_in ~aux_out_f]
      runs the filter [f] with the file input and output arguments specified
      in [args], and the auxiliary input [aux_in]; it then outputs the
      auxiliary output to the file named by [aux_out_filename], using
      [aux_out_f], or otherwise discards it. It returns any errors arising. *)
end

(** Signature of modules describing argument bundles that include the
    standard `act asm` arguments. *)
module type S_standard_asm = sig
  type t
  (** Opaque type of processed argument records. *)

  include S_standard_with_files with type t := t

  val aux_file : t -> string option
  (** [aux_file args] gets the path of a litmus aux file, if user supplied
      one. *)

  val target : t -> Asm_target.t
  (** [target args] gets either a defined assembly architecture, or a
      compiler ID. *)

  val sanitiser_passes :
    t -> Act_sanitiser.Pass_group.Selector.t Blang.t option
  (** [sanitiser_passes args] gets the Blang predicate, if any, supplied to
      filter the sanitiser pass selection. *)
end
