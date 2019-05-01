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

open Base
open Lib

include module type of Sim_intf

module Result : sig
  type t = [`Success of Sim_output.t | `Disabled | `Errored]
end

module File_map : sig
  type t
  (** Opaque type of file maps *)

  val make : (Fpath.t, Result.t) List.Assoc.t -> t Or_error.t
  (** [make alist] makes a file map from an associative list of Litmus file paths
      and simulator results. *)

  val get : t -> litmus_path:Fpath.t -> Result.t
  (** [get t ~litmus_path] gets the simulator result for Litmus path ~litmus_path. *)
end

module Make (B : Common_intf.Basic) : S with type file_map := File_map.t
