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

(** Interacting with a C preprocessor *)

(** {2 Filters} *)

(** [Filter] exposes a filter interface onto a configured C preprocessor. *)
module Filter :
  Plumbing.Filter_types.S
  with type aux_i = Act_config.Cpp.t
   and type aux_o = unit

(** [Chain_filter] exposes a filter that attaches in front of another filter
    [Dest] (that reads in C programs) and performs C preprocessing
    beforehand if the given config enables it. *)
module Chain_filter (Dest : Plumbing.Filter_types.S) :
  Plumbing.Filter_types.S
  with type aux_i = Act_config.Cpp.t * Dest.aux_i
   and type aux_o = Dest.aux_o