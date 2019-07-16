(* The Automagic Compiler Tormentor

   Copyright (c) 2018--2019 Matt Windsor and contributors

   ACT itself is licensed under the MIT License. See the LICENSE file in the
   project root for more information.

   ACT is based in part on code from the Herdtools7 project
   (https://github.com/herd/herdtools7) : see the LICENSE.herd file in the
   project root for more information. *)

open Core (* for Filename.arg_type *)

open Act_common

let write_trace (_ : unit) (_ : Stdio.Out_channel.t) : unit Or_error.t =
  Result.ok_unit

let run ?(seed : int option) ?(trace_output : string option)
    (args : Args.Standard_with_files.t) (o : Output.t)
    (act_config : Act_config.Act.t) : unit Or_error.t =
  let config =
    act_config |> Act_config.Act.fuzz
    |> Option.value ~default:(Act_config.Fuzz.make ())
  in
  Args.Standard_with_files.run_filter_with_aux_out
    (module Act_fuzz.Filter)
    args ~aux_in:{seed; o; config} ~aux_out_f:write_trace
    ?aux_out_filename:trace_output

let readme () : string =
  Act_utils.My_string.format_for_readme
    {|
This command takes, as input, a C litmus test.  It then performs various
mutations to the litmus test, and outputs the resulting modified test.
|}

let command : Command.t =
  Command.basic ~summary:"performs fuzzing mutations on a C litmus test"
    ~readme
    Command.Let_syntax.(
      let%map_open standard_args =
        ignore anon ; Args.Standard_with_files.get
      and seed =
        flag "seed" (optional int)
          ~doc:"INT use this integer as the seed to the fuzzer RNG"
      and trace_output =
        flag "trace-output"
          (optional Filename.arg_type)
          ~doc:
            "FILE if given, the filename to write auxiliary litmus \
             information to"
      in
      fun () ->
        Common.lift_command_with_files standard_args
          ~with_compiler_tests:false ~f:(run ?seed ?trace_output))
