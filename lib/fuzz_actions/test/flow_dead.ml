(* The Automagic Compiler Tormentor

   Copyright (c) 2018, 2019, 2020 Matt Windsor and contributors

   ACT itself is licensed under the MIT License. See the LICENSE file in the
   project root for more information.

   ACT is based in part on code from the Herdtools7 project
   (https://github.com/herd/herdtools7) : see the LICENSE.herd file in the
   project root for more information. *)

open Import

let%test_module "Early_out" =
  ( module struct
    let test_on_example_program (wherez : Fuzz.Path.Flagged.t Lazy.t)
        (to_insert : Act_fir.Early_out.t) : unit =
      let where = Lazy.force wherez in
      let initial_state : Fuzz.State.t =
        Lazy.force Fuzz_test.Subject.Test_data.state
      in
      let test : Fuzz.Subject.Test.t =
        Lazy.force Fuzz_test.Subject.Test_data.test
      in
      let payload = Fuzz.Payload_impl.Pathed.make ~where to_insert in
      Fuzz_test.Action.Test_utils.run_and_dump_test
        (Src.Flow_dead.Insert.Early_out.run test ~payload)
        ~initial_state

    (* TODO(@MattWindsor91): invalid paths *)

    let%expect_test "valid break on example program" =
      test_on_example_program
        Fuzz_test.Subject.Test_data.Path.insert_dead_loop Break ;
      [%expect
        {|
      void
      P0(atomic_int *x, atomic_int *y)
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
              atomic_store_explicit(y,
                                    atomic_load_explicit(x, memory_order_seq_cst),
                                    memory_order_seq_cst);
          }
          do { atomic_store_explicit(x, 44, memory_order_seq_cst); } while (4 ==
          5);
          for (r1 = 0; r1 <= 2; r1++)
          { atomic_store_explicit(x, 99, memory_order_seq_cst); }
          while (4 == 5)
          { break; atomic_store_explicit(x, 44, memory_order_seq_cst); }
      }

      void
      P1(atomic_int *x, atomic_int *y)
      { loop: ; if (true) {  } else { goto loop; } } |}]

    let%expect_test "invalid break on example program" =
      test_on_example_program Fuzz_test.Subject.Test_data.Path.insert_dead
        Break ;
      [%expect
        {|
      ("checking flags on insertion" "Unmet required flag condition: in-loop") |}]

    let%expect_test "valid return on example program" =
      test_on_example_program Fuzz_test.Subject.Test_data.Path.insert_dead
        Return ;
      [%expect
        {|
      void
      P0(atomic_int *x, atomic_int *y)
      {
          atomic_int r0 = 4004;
          int r1 = 8008;
          atomic_store_explicit(x, 42, memory_order_seq_cst);
          ;
          atomic_store_explicit(y, foo, memory_order_relaxed);
          if (foo == y)
          { atomic_store_explicit(x, 56, memory_order_seq_cst); kappa_kappa: ; }
          else { return; }
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
      P1(atomic_int *x, atomic_int *y)
      { loop: ; if (true) {  } else { goto loop; } } |}]
  end )
