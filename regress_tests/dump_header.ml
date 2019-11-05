(* The Automagic Compiler Tormentor

   Copyright (c) 2018--2019 Matt Windsor and contributors

   ACT itself is licensed under the MIT License. See the LICENSE file in the
   project root for more information.

   ACT is based in part on code from the Herdtools7 project
   (https://github.com/herd/herdtools7) : see the LICENSE.herd file in the
   project root for more information. *)

(** Tests the output of the 'act-c dump-header' command. *)

open Core
module Ac = Act_common

let dump_header_of_file ~(file : Fpath.t) ~(path : Fpath.t) : unit Or_error.t
    =
  ignore file ;
  Act_c_mini.Litmus_header.Filters.Dump.run ()
    (Plumbing.Input.of_fpath path)
    Plumbing.Output.stdout

let run (test_dir : Fpath.t) : unit Or_error.t =
  let full_dir = Fpath.(test_dir / "litmus" / "") in
  Common.regress_on_files "Delitmus" ~dir:full_dir ~ext:"litmus"
    ~f:dump_header_of_file

let command =
  Common.make_regress_command ~summary:"runs dump-header regressions" run

let () = Command.run command
