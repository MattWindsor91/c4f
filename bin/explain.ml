(* This file is part of 'act'.

   Copyright (c) 2018, 2019 by Matt Windsor

   Permission is hereby granted, free of charge, to any person
   obtaining a copy of this software and associated documentation
   files (the "Software"), to deal in the Software without
   restriction, including without limitation the rights to use, copy,
   modify, merge, publish, distribute, sublicense, and/or sell copies
   of the Software, and to permit persons to whom the Software is
   furnished to do so, subject to the following conditions:

   The above copyright notice and this permission notice shall be
   included in all copies or substantial portions of the Software.

   THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
   EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
   MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
   NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS
   BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN
   ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN
   CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
   SOFTWARE. *)

open Core
open Lib

let print_symbol_map = function
  | [] -> ()
  | map ->
    Format.printf "@[<v>@,Symbol map:@,@,%a@]@."
      (Format.pp_print_list
         ~pp_sep:Format.pp_print_space
         (fun f (k, v) -> Format.fprintf f "@[<hv>%s@ ->@ %s@]" k v))
      map
;;

let run
    file_type compiler_id_or_arch output_format (user_cvars : string list option)
    (args : Args.Standard_with_files.t) o cfg =
  let open Or_error.Let_syntax in
  let%bind target = Common.get_target cfg compiler_id_or_arch in
  let passes =
    Config.M.sanitiser_passes cfg ~default:Sanitiser_pass.explain
  in
  let explain_cfg = Asm_job.Explain_config.make ?format:output_format () in
  let%bind (module Exp) = Common.explain_pipeline target in
  let compiler_input_fn =
    Common.make_compiler_input o file_type user_cvars explain_cfg passes
  in
  let%map (_, (_, out)) =
    Exp.run_from_string_paths (file_type, compiler_input_fn)
      ~infile:(Args.Standard_with_files.infile_raw args)
      ~outfile:(Args.Standard_with_files.outfile_raw args)
  in
  Asm_job.warn out o.Output.wf;
  print_symbol_map (Asm_job.symbol_map out)
;;

let command =
  let open Command.Let_syntax in
  Command.basic
    ~summary:"explains act's understanding of an assembly file"
    [%map_open
      let standard_args = Args.Standard_with_files.get
      and sanitiser_passes = Args.sanitiser_passes
      and compiler_id_or_arch = Args.compiler_id_or_arch
      and c_symbols = Args.c_symbols
      and output_format =
        Asm_job.Explain_config.Format.(
          choose_one
            [ map ~f:(fun flag -> Option.some_if flag (Some Detailed))
                (flag "detailed"
                   no_arg
                   ~doc: "Print a detailed (but long-winded) explanation")
            ; map ~f:(fun flag -> Option.some_if flag (Some Assembly))
                (flag "as-assembly"
                   no_arg
                   ~doc: "Print explanation as lightly annotated assembly")
            ]
            ~if_nothing_chosen:(`Default_to None)
        )
      and file_type = Args.file_type
      in
      fun () ->
        Common.lift_command_with_files standard_args
          ?sanitiser_passes
          ~with_compiler_tests:false
          ~f:(run
                file_type
                compiler_id_or_arch
                output_format
                c_symbols)
    ]
;;