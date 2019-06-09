(* The Automagic Compiler Tormentor

   Copyright (c) 2018--2019 Matt Windsor and contributors

   ACT itself is licensed under the MIT License. See the LICENSE file in the
   project root for more information.

   ACT is based in part on code from the Herdtools7 project
   (https://github.com/herd/herdtools7) : see the LICENSE.herd file in the
   project root for more information. *)

open Base
open Stdio
open Act_config
module Ac = Act_common
module Am = Act_machine

module Data = struct
  let cpp : Cpp.t Lazy.t = Lazy.from_fun Cpp.default

  let fuzz : Fuzz.t Lazy.t = Lazy.from_fun Fuzz.make

  (* These defaults should line up with the ones in Machine.Test.Qualified.

     TODO(@MattWindsor91): unify them. *)

  let defaults : Default.t Lazy.t =
    Lazy.from_fun
      Ac.Id.(
        Default.make
          ~machines:[of_string "foo"; of_string "bar"; of_string "localhost"]
          ~compilers:[of_string "localhost.gcc.x86.normal"]
          ~arches:[of_string "x86.att"])

  let machines : Am.Spec.Set.t Lazy.t =
    Act_machine_test.Data.Spec_sets.single_local_machine

  let global : Global.t Lazy.t =
    Lazy.Let_syntax.(
      let%map cpp = cpp
      and fuzz = fuzz
      and defaults = defaults
      and machines = machines in
      Global.make ~cpp ~fuzz ~defaults ~machines ())
end

let%test_module "accessors" =
  ( module struct
    let global = Lazy.force Data.global

    let%expect_test "cpp" =
      print_s [%sexp (Global.cpp global : Cpp.t option)] ;
      [%expect {| (((enabled true) (cmd ()) (argv ()))) |}]

    let%expect_test "defaults" =
      print_s [%sexp (Global.defaults global : Default.t)] ;
      [%expect
        {|
          ((arches ((x86 att))) (compilers ((localhost gcc x86 normal)))
           (machines ((foo) (bar) (localhost))) (sims ())) |}]

    let%expect_test "fuzz" =
      print_s [%sexp (Global.fuzz global : Fuzz.t option)] ;
      [%expect {| (((weights ()))) |}]

    let%expect_test "machines" =
      Fmt.pr "@[%a@]@." Am.Spec.Set.pp (Global.machines global) ;
      [%expect {| localhost: local |}]
  end )
