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
module A = Act_common

type t = Arch of A.Id.t | Compiler_id of A.Id.t [@@deriving variants]

let resolve_compiler (cfg : Act_config.Act.t) (fqid : A.Id.t) :
    Act_compiler.Target.t Or_error.t =
  Or_error.Let_syntax.(
    let%map spec = Act_config.Act.compiler cfg ~fqid in
    `Spec spec)

let resolve (target : t) ~(cfg : Act_config.Act.t) :
    Act_compiler.Target.t Or_error.t =
  Variants.map
    ~compiler_id:(fun _ -> resolve_compiler cfg)
    ~arch:(fun _ arch -> Or_error.return (`Arch arch))
    target