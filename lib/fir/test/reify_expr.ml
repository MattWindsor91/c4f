(* The Automagic Compiler Tormentor

   Copyright (c) 2018--2019 Matt Windsor and contributors

   ACT itself is licensed under the MIT License. See the LICENSE file in the
   project root for more information.

   ACT is based in part on code from the Herdtools7 project
   (https://github.com/herd/herdtools7) : see the LICENSE.herd file in the
   project root for more information. *)

open Base
module Src = Act_fir

let%test_module "examples" =
  ( module struct
    let test (x : Src.Expression.t) : unit =
      let rx = Src.Reify_expr.reify x in
      Fmt.pr "@[%a@]@." Act_litmus_c.Ast.Expr.pp rx

    let%expect_test "subtract bracketing 1" =
      test
        Src.Expression.(
          sub (sub (int_lit 1) (int_lit 1)) (sub (int_lit 1) (int_lit 1))) ;
      [%expect {| 1 - 1 - (1 - 1) |}]

    let%expect_test "subtract bracketing 2" =
      test
        Src.Expression.(
          sub (sub (sub (int_lit 1) (int_lit 1)) (int_lit 1)) (int_lit 1)) ;
      [%expect {| 1 - 1 - 1 - 1 |}]

    let%expect_test "subtract bracketing 3" =
      test
        Src.Expression.(
          sub (int_lit 1) (sub (int_lit 1) (sub (int_lit 1) (int_lit 1)))) ;
      [%expect {| 1 - (1 - (1 - 1)) |}]

    let%expect_test "add-subtract bracketing" =
      test
        Src.Expression.(
          sub (add (sub (int_lit 1) (int_lit 2)) (int_lit 3)) (int_lit 4)) ;
      [%expect {| 1 - 2 + 3 - 4 |}]

    let%expect_test "atomic_load of referenced variable" =
      test
        Src.(
          Expression.atomic_load
            (Atomic_load.make
               ~src:(Address.of_variable_ref (Act_common.C_id.of_string "x"))
               ~mo:Mem_order.Seq_cst)) ;
      [%expect {| atomic_load_explicit(&x, memory_order_seq_cst) |}]
  end )

let%test_module "round trips" =
  ( module struct
    let test_round_trip
        (module Qc : Act_utils.My_quickcheck.S_with_sexp
          with type t = Src.Expression.t) : unit =
      Base_quickcheck.Test.run_exn
        (module Qc)
        ~f:(fun exp ->
          [%test_result: Src.Expression.t Or_error.t] ~here:[[%here]]
            ~expect:(Ok exp)
            (Src.Convert.expr (Src.Reify_expr.reify exp)) )

    module Make (F : functor (A : Src.Env_types.S) ->
      Act_utils.My_quickcheck.S_with_sexp with type t = Src.Expression.t) =
    struct
      let run_round_trip () : unit =
        let env = Lazy.force Env.test_env in
        let module Qc = F (struct
          let env = env
        end) in
        test_round_trip (module Qc)
    end

    module Int_values = Make (Src.Expression_gen.Int_values)

    let%test_unit "round-trip on integer expressions" =
      Int_values.run_round_trip ()

    module Int_zeroes = Make (Src.Expression_gen.Int_zeroes)

    let%test_unit "round-trip on integer zeroes" =
      Int_zeroes.run_round_trip ()

    module Bool_values = Make (Src.Expression_gen.Bool_values)

    let%test_unit "round-trip on Boolean expressions" =
      Bool_values.run_round_trip ()

    module Bool_tautologies_in (E : Src.Env_types.S) = struct
      module K = Src.Expression_gen.Bool_known (E)
      include K.Tautologies
    end

    module Bool_tautologies = Make (Bool_tautologies_in)

    let%test_unit "round-trip on Boolean tautologies" =
      Bool_tautologies.run_round_trip ()

    module Bool_falsehoods_in (E : Src.Env_types.S) = struct
      module K = Src.Expression_gen.Bool_known (E)
      include K.Tautologies
    end

    module Bool_falsehoods = Make (Bool_falsehoods_in)

    let%test_unit "round-trip on Boolean falsehoods" =
      Bool_falsehoods.run_round_trip ()
  end )
