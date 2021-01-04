(* This file is part of c4f.

   Copyright (c) 2018-2021 C4 Project

   c4t itself is licensed under the MIT License. See the LICENSE file in the
   project root for more information.

   Parts of c4t are based on code from the Herdtools7 project
   (https://github.com/herd/herdtools7) : see the LICENSE.herd file in the
   project root for more information. *)

open Core_kernel

open struct
  module Ac = C4f_common
end

let readme () : string =
  C4f_utils.My_string.format_for_readme
    {|
      Reads the current config file, and outputs information about each
      tunable fuzzer parameter, including its computed value
      after taking the config into consideration.

      If verbose mode is enabled, the information is a detailed summary of the
      parameter, including its documentation; otherwise, this command prints
      only the name and current value.
    |}

let summaries_of_config (cfg : C4f_config.Global.t) :
    C4f_fuzz_run.Config.Param_summary.t Or_error.t =
  cfg |> C4f_config.Global.fuzz
  |> C4f_fuzz_run.Config.Param_summary.summarise

let print (o : Ac.Output.t) (map : C4f_fuzz_run.Config.Param_summary.t) :
    unit =
  let pp =
    C4f_fuzz_run.Config.Param_summary.(
      if Ac.Output.is_verbose o then pp else pp_terse)
  in
  Fmt.pr "@[<v>%a@]@." pp map

let run (o : Ac.Output.t) (cfg : C4f_config.Global.t) : unit Or_error.t =
  Or_error.(cfg |> summaries_of_config >>| print o)

let command : Command.t =
  Command.basic ~summary:"output the current fuzzer param map" ~readme
    Command.Let_syntax.(
      let%map standard_args = Common_cmd.Args.Standard.get in
      fun () ->
        Common_cmd.Args.Standard.lift_command_with_config standard_args
          ~f:run)
