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

let readme () : string =
  Act_utils.My_string.format_for_readme
    {|
The `asm` command group contains commands for querying and manipulating
single assembly files or litmus tests.

Some of the commands also generalise to single C files or litmus tests, by
passing them through a nominated compiler and, if necessary, `act`'s
delitmusifier.  For target-independent operations on single C files/tests,
see the `c` command group.
|}

let command : Command.t =
  Command.group ~summary:"commands for dealing with assembly files" ~readme
    [ ("explain", Asm_explain.command)
    ; ("gen-stubs", Asm_gen_stubs.command)
    ; ("litmusify", Asm_litmusify.command) ]