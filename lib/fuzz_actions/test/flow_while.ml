(* The Automagic Compiler Tormentor

   Copyright (c) 2018, 2019, 2020 Matt Windsor and contributors

   ACT itself is licensed under the MIT License. See the LICENSE file in the
   project root for more information.

   ACT is based in part on code from the Herdtools7 project
   (https://github.com/herd/herdtools7) : see the LICENSE.herd file in the
   project root for more information. *)

open Base
open Import

let%test_module "test runs" =
  ( module struct
    (* TODO(@MattWindsor91): sort out the discrepancy between the subject
       example and var map. Also sort out duplication with below. *)

    let state : Fuzz.State.t =
      Fuzz.State.make ~vars:(Lazy.force Fuzz_test.Var.Test_data.test_map) ()

    let test : Fuzz.Subject.Test.t =
      Lazy.force Fuzz_test.Subject.Test_data.test

    let cond : Fir.Expression.t =
      (* should be false with respect to the var map *)
      Fir.(
        Expression.(
          l_and
            (eq (of_variable_str_exn "y") (int_lit 27))
            (of_variable_str_exn "a")))

    let%test_module "While.Insert.False" =
      ( module struct
        let payload : Src.Flow_while.Insert.False.Payload.t =
          Fuzz.Payload_impl.Pathed.make cond
            ~where:(Lazy.force Fuzz_test.Subject.Test_data.Path.insert_live)

        let action = Src.Flow_while.Insert.False.run test ~payload

        let%expect_test "resulting AST" =
          Fuzz_test.Action.Test_utils.run_and_dump_test action
            ~initial_state:state ;
          [%expect
            {|
          void
          P0(bool a, atomic_bool b, atomic_int bar, bool barbaz, atomic_int *baz,
             bool c, int d, int e, int foo, atomic_bool foobar, atomic_int x,
             atomic_int y)
          {
              atomic_int r0 = 4004;
              int r1 = 8008;
              atomic_store_explicit(x, 42, memory_order_seq_cst);
              ;
              while (y == 27 && a) {  }
              atomic_store_explicit(y, foo, memory_order_relaxed);
              if (foo == y)
              { atomic_store_explicit(x, 56, memory_order_seq_cst); kappa_kappa: ; }
              if (false)
              {
                  atomic_store_explicit(y,
                                        atomic_load_explicit(x, memory_order_seq_cst),
                                        memory_order_seq_cst);
              }
              do { atomic_store_explicit(x, 44, memory_order_seq_cst); } while (4 ==
              5);
              for (r1 = 0; r1 <= 2; r1++)
              { atomic_store_explicit(x, 99, memory_order_seq_cst); }
              while (4 == 5) { atomic_store_explicit(x, 44, memory_order_seq_cst); }
          }

          void
          P1(bool a, atomic_bool b, atomic_int bar, bool barbaz, atomic_int *baz,
             bool c, int d, int e, int foo, atomic_bool foobar, atomic_int x,
             atomic_int y)
          { loop: ; if (true) {  } else { goto loop; } } |}]

        let%expect_test "global dependencies after running" =
          Fuzz_test.Action.Test_utils.run_and_dump_global_deps action
            ~initial_state:state ;
          [%expect {|
          a=false y=53 |}]
      end )

    let%test_module "While.Surround.Do_false" =
      ( module struct
        module Surround = Src.Flow_while.Surround.Do_false

        let payload : Fuzz.Payload_impl.Cond_pathed.t =
          Fuzz.Payload_impl.Pathed.make cond
            ~where:
              (Lazy.force Fuzz_test.Subject.Test_data.Path.surround_atomic)

        let action = Surround.run test ~payload

        let%expect_test "resulting AST" =
          Fuzz_test.Action.Test_utils.run_and_dump_test action
            ~initial_state:state ;
          [%expect
            {|
          void
          P0(bool a, atomic_bool b, atomic_int bar, bool barbaz, atomic_int *baz,
             bool c, int d, int e, int foo, atomic_bool foobar, atomic_int x,
             atomic_int y)
          {
              atomic_int r0 = 4004;
              int r1 = 8008;
              do { atomic_store_explicit(x, 42, memory_order_seq_cst); ; } while (y ==
              27 && a);
              atomic_store_explicit(y, foo, memory_order_relaxed);
              if (foo == y)
              { atomic_store_explicit(x, 56, memory_order_seq_cst); kappa_kappa: ; }
              if (false)
              {
                  atomic_store_explicit(y,
                                        atomic_load_explicit(x, memory_order_seq_cst),
                                        memory_order_seq_cst);
              }
              do { atomic_store_explicit(x, 44, memory_order_seq_cst); } while (4 ==
              5);
              for (r1 = 0; r1 <= 2; r1++)
              { atomic_store_explicit(x, 99, memory_order_seq_cst); }
              while (4 == 5) { atomic_store_explicit(x, 44, memory_order_seq_cst); }
          }

          void
          P1(bool a, atomic_bool b, atomic_int bar, bool barbaz, atomic_int *baz,
             bool c, int d, int e, int foo, atomic_bool foobar, atomic_int x,
             atomic_int y)
          { loop: ; if (true) {  } else { goto loop; } } |}]

        let%expect_test "global dependencies after running" =
          Fuzz_test.Action.Test_utils.run_and_dump_global_deps action
            ~initial_state:state ;
          [%expect {|
          a=false y=53 |}]
      end )

    let%test_module "While.Surround.Do_dead" =
      ( module struct
        module Surround = Src.Flow_while.Surround.Do_dead

        (* TODO(@MattWindsor91): sort out the discrepancy between the subject
           example and var map. *)

        let payload : Fuzz.Payload_impl.Cond_pathed.t =
          Fuzz.Payload_impl.Pathed.make cond
            ~where:
              (Lazy.force Fuzz_test.Subject.Test_data.Path.surround_dead)

        let action = Surround.run test ~payload

        let%expect_test "resulting AST" =
          Fuzz_test.Action.Test_utils.run_and_dump_test action
            ~initial_state:state ;
          [%expect
            {|
          void
          P0(bool a, atomic_bool b, atomic_int bar, bool barbaz, atomic_int *baz,
             bool c, int d, int e, int foo, atomic_bool foobar, atomic_int x,
             atomic_int y)
          {
              atomic_int r0 = 4004;
              int r1 = 8008;
              atomic_store_explicit(x, 42, memory_order_seq_cst);
              ;
              atomic_store_explicit(y, foo, memory_order_relaxed);
              if (foo == y)
              { atomic_store_explicit(x, 56, memory_order_seq_cst); kappa_kappa: ; }
              if (false)
              {
                  do
                  {
                      atomic_store_explicit(y,
                                            atomic_load_explicit(x,
                                                                 memory_order_seq_cst),
                                            memory_order_seq_cst);
                  } while (y == 27 && a);
              }
              do { atomic_store_explicit(x, 44, memory_order_seq_cst); } while (4 ==
              5);
              for (r1 = 0; r1 <= 2; r1++)
              { atomic_store_explicit(x, 99, memory_order_seq_cst); }
              while (4 == 5) { atomic_store_explicit(x, 44, memory_order_seq_cst); }
          }

          void
          P1(bool a, atomic_bool b, atomic_int bar, bool barbaz, atomic_int *baz,
             bool c, int d, int e, int foo, atomic_bool foobar, atomic_int x,
             atomic_int y)
          { loop: ; if (true) {  } else { goto loop; } } |}]

        let%expect_test "global dependencies after running" =
          Fuzz_test.Action.Test_utils.run_and_dump_global_deps action
            ~initial_state:state ;
          [%expect {| |}]
      end )

    let%test_module "While.Surround.Dead" =
      ( module struct
        module Surround = Src.Flow_while.Surround.Dead

        let payload : Fuzz.Payload_impl.Cond_pathed.t =
          Fuzz.Payload_impl.Pathed.make cond
            ~where:
              (Lazy.force Fuzz_test.Subject.Test_data.Path.surround_dead)

        let action = Surround.run test ~payload

        let%expect_test "resulting AST" =
          Fuzz_test.Action.Test_utils.run_and_dump_test action
            ~initial_state:state ;
          [%expect
            {|
          void
          P0(bool a, atomic_bool b, atomic_int bar, bool barbaz, atomic_int *baz,
             bool c, int d, int e, int foo, atomic_bool foobar, atomic_int x,
             atomic_int y)
          {
              atomic_int r0 = 4004;
              int r1 = 8008;
              atomic_store_explicit(x, 42, memory_order_seq_cst);
              ;
              atomic_store_explicit(y, foo, memory_order_relaxed);
              if (foo == y)
              { atomic_store_explicit(x, 56, memory_order_seq_cst); kappa_kappa: ; }
              if (false)
              {
                  while (y == 27 && a)
                  {
                      atomic_store_explicit(y,
                                            atomic_load_explicit(x,
                                                                 memory_order_seq_cst),
                                            memory_order_seq_cst);
                  }
              }
              do { atomic_store_explicit(x, 44, memory_order_seq_cst); } while (4 ==
              5);
              for (r1 = 0; r1 <= 2; r1++)
              { atomic_store_explicit(x, 99, memory_order_seq_cst); }
              while (4 == 5) { atomic_store_explicit(x, 44, memory_order_seq_cst); }
          }

          void
          P1(bool a, atomic_bool b, atomic_int bar, bool barbaz, atomic_int *baz,
             bool c, int d, int e, int foo, atomic_bool foobar, atomic_int x,
             atomic_int y)
          { loop: ; if (true) {  } else { goto loop; } } |}]

        let%expect_test "global dependencies after running" =
          Fuzz_test.Action.Test_utils.run_and_dump_global_deps action
            ~initial_state:state ;
          [%expect {| |}]
      end )
  end )
