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

open Core_kernel
module A = Act_common

let readme () : string =
  Utils.My_string.format_for_readme
    {|
The `asm gen-stubs` command generates GCC assembly directives that can
be slotted into a simulation harness.
|}

let run
  (file_type : [> `Assembly | `C | `C_litmus | `Infer])
  (compiler_id_or_arch : [> `Arch of A.Id.t | `Id of A.Id.t])
  (c_globals : string list option)
  (c_locals : string list option)
  (args : Args.Standard_with_files.t)
  (o : A.Output.t)
  (cfg : Config.Act.t)
  : unit Or_error.t =
  ignore file_type;
  ignore compiler_id_or_arch;
  ignore c_globals;
  ignore c_locals;
  ignore args;
  ignore o;
  ignore cfg;
  Or_error.unimplemented "TODO"

let command : Command.t =
  Command.basic ~summary:"generates GCC asm stubs from an assembly file"
    ~readme
    Command.Let_syntax.(
      let%map_open standard_args = Args.Standard_with_files.get
      and sanitiser_passes = Args.sanitiser_passes
      and compiler_id_or_arch = Args.compiler_id_or_arch
      and c_globals = Args.c_globals
      and c_locals = Args.c_locals
      and file_type = Args.file_type in
      fun () ->
        Common.lift_command_with_files standard_args ?sanitiser_passes
          ~with_compiler_tests:false
          ~f:
            (run file_type compiler_id_or_arch c_globals
               c_locals))
