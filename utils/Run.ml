(* This file is part of 'act'.

Copyright (c) 2018 by Matt Windsor

Permission is hereby granted, free of charge, to any person obtaining
a copy of this software and associated documentation files (the
"Software"), to deal in the Software without restriction, including
without limitation the rights to use, copy, modify, merge, publish,
distribute, sublicense, and/or sell copies of the Software, and to
permit persons to whom the Software is furnished to do so, subject to
the following conditions:

The above copyright notice and this permission notice shall be
included in all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE
LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION
OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION
WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE. *)

(** Quick and easy process running *)

open Core
open Core_extended

type exit_code =
  { cmd   : string list
  ; code  : int
  } [@@deriving sexp]

type exit_sig =
  { cmd    : string list
  ; signal : Signal.t
  } [@@deriving sexp]

module type Runner = sig
  val run
    :  ?oc:Out_channel.t
    -> prog:string
    -> string list
    -> unit Or_error.t
end

module Local : Runner = struct
  let run ?oc ~prog args =
    let open Or_error.Let_syntax in
    let stdoutf =
      match oc with
      | None -> Fn.const (Fn.const ())
      | Some o -> fun buf len -> Out_channel.output o ~buf ~pos:0 ~len
    in
    let stderrf buf len =
      Out_channel.output Out_channel.stderr ~buf ~pos:0 ~len
    in
    let%bind out =
      Or_error.tag_arg
        (Or_error.try_with_join
           (fun () -> return (Process.run ~prog ~args ~stdoutf ~stderrf ())))
        "Failed to run a child process:"
        (prog::args)
        [%sexp_of: string list]
    in
    match out.status with
    | `Timeout _ ->
      Or_error.error_string "timed out"
    | `Exited 0 -> Result.ok_unit
    | `Exited code ->
      Or_error.error
        "process exited with nonzero status"
        { cmd = prog::args; code }
        [%sexp_of: exit_code]
    | `Signaled signal ->
      Or_error.error
        "process caught signal"
        { cmd = prog::args; signal }
        [%sexp_of: exit_sig]
end

module type SshConf = sig
  val host : string
  val user : string option
end

module Ssh (C : SshConf) : Runner = struct
  let run ?oc ~prog args =
    let open Or_error in
    let open Or_error.Let_syntax in
    let%bind output =
      tag_arg
        (try_with
           (fun () ->
              Shell.ssh_lines "%s %s" prog (String.concat ~sep:" " args)
                ~host:C.host ?user:C.user))
        "Error running remote command via ssh:"
        (C.host, Option.value ~default:"(default user)" C.user)
        [%sexp_of: string * string]
    in
    Option.iter
      ~f:(fun o -> Out_channel.output_lines o output)
      oc;
    Result.ok_unit
end
