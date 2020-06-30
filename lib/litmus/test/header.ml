(* The Automagic Compiler Tormentor

   Copyright (c) 2018--2019 Matt Windsor and contributors

   ACT itself is licensed under the MIT License. See the LICENSE file in the
   project root for more information.

   ACT is based in part on code from the Herdtools7 project
   (https://github.com/herd/herdtools7) : see the LICENSE.herd file in the
   project root for more information. *)

open Base
open Stdio
module A = Act_litmus.Header
module Ac = Act_common

module J = A.Json (struct
  include Int

  let yojson_of_t (i : t) : Yojson.Safe.t = `Int i

  let t_of_yojson : Yojson.Safe.t -> int = Yojson.Safe.Util.to_int

  let parse_post_string (s : string) :
      int Act_litmus.Postcondition.t Or_error.t =
    Or_error.try_with (fun () ->
        s |> Parsexp.Single.parse_string_exn
        |> [%of_sexp: int Act_litmus.Postcondition.t] )
end)

let%test_module "JSON deserialisation" =
  ( module struct
    type t = int A.t

    let test (header : t) : unit =
      let json = J.yojson_of_t header in
      Yojson.Safe.pretty_to_channel ~std:true stdout json

    let%expect_test "empty header" =
      test A.empty ;
      [%expect
        {| { "name": "", "locations": null, "init": {}, "postcondition": null } |}]

    let%expect_test "SBSC example header" =
      test (Lazy.force Examples.Sbsc.header) ;
      [%expect
        {|
        {
          "name": "SBSC",
          "locations": [ "x", "y" ],
          "init": { "x": 0, "y": 0 },
          "postcondition": "exists (0:a == 0 /\\ 1:a == 1)"
        } |}]
  end )

let%test_module "JSON serialisation" =
  ( module struct
    let test (json_str : string) : unit =
      let json = Yojson.Safe.from_string json_str in
      let header = J.t_of_yojson json in
      print_s [%sexp (header : int A.t)]

    let%expect_test "SBSC example header without a postcondition" =
      test
        {|
        {
          "name": "SBSC",
          "locations": [ "x", "y" ],
          "init": { "x": 0, "y": 0 }
        }
        |} ;
      [%expect
        {|
          ((locations ((x y))) (init ((x 0) (y 0))) (postcondition ()) (name SBSC)) |}]
  end )

(* TODO(@MattWindsor91): test with postcondition *)
