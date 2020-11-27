(* The Automagic Compiler Tormentor

   Copyright (c) 2018, 2019, 2020 Matt Windsor and contributors

   ACT itself is licensed under the MIT License. See the LICENSE file in the
   project root for more information.

   ACT is based in part on code from the Herdtools7 project
   (https://github.com/herd/herdtools7) : see the LICENSE.herd file in the
   project root for more information. *)

open Base
open Stdio

open struct
  module Src = Act_config
end

module Data = struct
  let fuzz : Act_fuzz_run.Config.t Lazy.t =
    Lazy.from_fun Act_fuzz_run.Config.make

  let global : Src.Global.t Lazy.t =
    Lazy.Let_syntax.(
      let%map fuzz = fuzz in
      Src.Global.make ~fuzz ())
end

let%test_module "accessors" =
  ( module struct
    let global = Lazy.force Data.global

    let%expect_test "fuzz" =
      print_s [%sexp (Src.Global.fuzz global : Act_fuzz_run.Config.t)] ;
      [%expect {| ((weights ()) (params ()) (flags ())) |}]
  end )
