(* The Automagic Compiler Tormentor

   Copyright (c) 2018--2019 Matt Windsor and contributors

   ACT itself is licensed under the MIT License. See the LICENSE file in the
   project root for more information.

   ACT is based in part on code from the Herdtools7 project
   (https://github.com/herd/herdtools7) : see the LICENSE.herd file in the
   project root for more information. *)

open Core_kernel
open Stdio
open Act_c.Mini_address

let%test_module "variable_of" =
  ( module struct
    let%test_unit "variable_of: preserved by ref" =
      Base_quickcheck.Test.run_exn
        (module Act_c.Mini_address)
        ~f:(fun x ->
          [%test_eq: Act_common.C_id.t] ~here:[[%here]] (variable_of x)
            (variable_of (ref x)))

    let%expect_test "variable_of: nested example" =
      let example =
        ref
          (ref
             (lvalue
                Act_c.(
                  Mini_lvalue.deref
                    (Mini_lvalue.variable
                       (Act_common.C_id.of_string "yorick")))))
      in
      let var = variable_of example in
      Fmt.pr "%a@." Act_common.C_id.pp var ;
      [%expect {| yorick |}]
  end )

let%test_module "Type-check" =
  ( module struct
    module T = Type_check ((val Lazy.force Act_c.Mini_env.test_env_mod))

    let test (addr : t) : unit =
      let result = T.type_of addr in
      print_s [%sexp (result : Act_c.Mini_type.t Or_error.t)]

    let%expect_test "Type-checking a valid normal variable lvalue" =
      test (of_variable (Act_common.C_id.of_string "foo")) ;
      [%expect {| (Ok (Normal int)) |}]

    let%expect_test "Type-checking an valid reference lvalue" =
      test (of_variable_ref (Act_common.C_id.of_string "foo")) ;
      [%expect {| (Ok (Pointer_to int)) |}]
  end )

let%test_unit "on_address_of_typed_id: always takes pointer type" =
  let (module E) = Lazy.force Act_c.Mini_env.test_env_mod in
  let module Tc = Type_check (E) in
  Base_quickcheck.Test.run_exn
    (module E.Random_var)
    ~f:(fun id ->
      let ty = Act_common.C_id.Map.find_exn E.env id in
      [%test_result: Act_c.Mini_type.t Or_error.t] ~here:[[%here]]
        (Tc.type_of (on_address_of_typed_id ~id ~ty))
        ~expect:
          (Or_error.return Act_c.Mini_type.(pointer_to (basic_type ty))))

let variable_in (module E : Act_c.Mini_env.S) (l : t) : bool =
  Act_common.C_id.Map.mem E.env (variable_of l)

let%test_unit "Quickcheck_on_env: liveness" =
  let e = Lazy.force Act_c.Mini_env.test_env_mod in
  let module Q = Quickcheck_on_env ((val e)) in
  Quickcheck.test_can_generate [%quickcheck.generator: Q.t]
    ~sexp_of:[%sexp_of: t] ~f:(variable_in e)

let%test_unit "Quickcheck_on_env: generated underlying variables in \
               environment" =
  let e = Lazy.force Act_c.Mini_env.test_env_mod in
  let module Q = Quickcheck_on_env ((val e)) in
  Base_quickcheck.Test.run_exn
    (module Q)
    ~f:([%test_pred: t] ~here:[[%here]] (variable_in e))

let%test_unit "Quickcheck_atomic_int_pointers: liveness" =
  let e = Lazy.force Act_c.Mini_env.test_env_mod in
  let module Q = Quickcheck_atomic_int_pointers ((val e)) in
  Quickcheck.test_can_generate [%quickcheck.generator: Q.t]
    ~sexp_of:[%sexp_of: t] ~trials:20 ~f:(variable_in e)

let%test_unit "Quickcheck_atomic_int_pointers: generated underlying \
               variables in environment" =
  let e = Lazy.force Act_c.Mini_env.test_env_mod in
  let module Q = Quickcheck_atomic_int_pointers ((val e)) in
  Base_quickcheck.Test.run_exn
    (module Q)
    ~f:([%test_pred: t] ~here:[[%here]] (variable_in e))

let%test_unit "Quickcheck_int_values: generated lvalues have '*atomic_int' \
               type" =
  let e = Lazy.force Act_c.Mini_env.test_env_mod in
  let module Q = Quickcheck_atomic_int_pointers ((val e)) in
  let module Tc = Type_check ((val e)) in
  Base_quickcheck.Test.run_exn
    (module Q)
    ~f:(fun lv ->
      [%test_result: Act_c.Mini_type.t Or_error.t] ~here:[[%here]]
        (Tc.type_of lv)
        ~expect:
          (Or_error.return Act_c.Mini_type.(pointer_to Basic.atomic_int)))