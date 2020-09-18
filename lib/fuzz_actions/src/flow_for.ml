(* The Automagic Compiler Tormentor

   Copyright (c) 2018, 2019, 2020 Matt Windsor and contributors

   ACT itself is licensed under the MIT License. See the LICENSE file in the
   project root for more information.

   ACT is based in part on code from the Herdtools7 project
   (https://github.com/herd/herdtools7) : see the LICENSE.herd file in the
   project root for more information. *)

open Base
open Import

let prefix_name (rest : Common.Id.t) : Common.Id.t =
  (* Shared with Flow_while. *)
  Common.Id.("flow" @: "loop" @: rest)

module Payload = struct
  module Counter = struct
    type t = {var: Common.Litmus_id.t; ty: Fir.Type.t} [@@deriving sexp]

    let lc_expr ({var; ty} : t) : Fir.Expression.t =
      let name = Common.Litmus_id.variable_name var in
      let lc_tvar = Common.C_named.make ty ~name in
      Fir.Expression.lvalue (Fir.Lvalue.on_value_of_typed_id lc_tvar)

    let declare_and_register ({var; ty} : t) (test : Fuzz.Subject.Test.t) :
        Fuzz.Subject.Test.t Fuzz.State.Monad.t =
      Fuzz.State.Monad.Let_syntax.(
        let value = Fir.Constant.zero_of_type ty in
        let init = Fir.Initialiser.make ~ty ~value in
        let%bind test' =
          Fuzz.State.Monad.register_and_declare_var var init test
        in
        (* Note that this sets the known value of the loop counter to 0, so
           we have to erase it again; otherwise, the for loop's activity on
           the loop counter would be ignored by the rest of the fuzzer and
           lead to semantic violations. *)
        let%bind () = Fuzz.State.Monad.erase_var_value var in
        let%map () = Fuzz.State.Monad.add_dependency var in
        test')
  end

  module Simple = struct
    type t =
      {lc: Counter.t; up_to: Fir.Constant.t; where: Fuzz.Path.Flagged.t}
    [@@deriving sexp, fields]

    let src_exprs (x : t) : Fir.Expression.t list =
      [ Fir.Expression.constant x.up_to
      ; (* The loop counter is effectively being read from as well as written
           to each iteration. *)
        Counter.lc_expr x.lc ]
  end

  module Kv = struct
    type t =
      { lc: Counter.t
      ; kv_val: Fir.Constant.t
      ; kv_expr: Fir.Expression.t
      ; where: Fuzz.Path.Flagged.t }
    [@@deriving sexp, fields]

    let src_exprs (x : t) : Fir.Expression.t list =
      [ x.kv_expr
      ; (* The loop counter is effectively being read from as well as written
           to each iteration. *)
        Counter.lc_expr x.lc ]

    let direction (i : Fir.Flow_block.For.Simple.Inclusivity.t)
        ({kv_val; _} : t) : Fir.Flow_block.For.Simple.Direction.t =
      (* Try to avoid overflows by only going up if we're negative. *)
      match Fir.Constant.as_int kv_val with
      | Ok x when x < 0 ->
          Up i
      | _ ->
          Down i

    let control (i : Fir.Flow_block.For.Simple.Inclusivity.t) (payload : t) :
        Act_fir.Flow_block.For.Simple.t =
      { lvalue=
          Accessor.construct Fir.Lvalue.variable
            (Common.Litmus_id.variable_name payload.lc.var)
      ; direction= direction i payload
      ; init_value= Fir.Expression.constant payload.kv_val
      ; cmp_value= payload.kv_expr }
  end
end

(* 'Payload' gets shadowed a lot later on. *)
open struct
  module Pd = Payload
end

module Surround = struct
  let prefix_name (x : Common.Id.t) : Common.Id.t =
    prefix_name Common.Id.("surround" @: "for" @: x)

  module Simple :
    Fuzz.Action_types.S with type Payload.t = Payload.Simple.t =
  Fuzz.Action.Make_surround (struct
    let name = prefix_name Common.Id.("simple" @: empty)

    let surround_with : string = "for-loops"

    let readme_suffix : string =
      {| The for loop initialises its (fresh) counter to zero, then counts
        upwards to a random, small, constant value.  This action does not
        surround non-generated or loop-unsafe statements. |}

    let path_filter (_ : Fuzz.Availability.Context.t) =
      Fuzz.Path_filter.(
        live_loop_surround
        @@ require_end_check ~check:(Stm_no_meta_restriction Once_only)
        @@ empty)

    let available : Fuzz.Availability.t =
      Fuzz.Availability.(
        M.(lift path_filter >>= is_filter_constructible ~kind:Transform_list))

    module Payload = struct
      include Payload.Simple

      let gen : t Fuzz.Payload_gen.t =
        Fuzz.Payload_gen.(
          let* filter =
            lift (Fn.compose path_filter Context.to_availability)
          in
          let* where = path_with_flags Transform_list ~filter in
          let scope = Common.Scope.Local (Fuzz.Path.tid where.path) in
          let* lc_var = fresh_var scope in
          let lc : Pd.Counter.t = {var= lc_var; ty= Fir.Type.int ()} in
          let+ up_to =
            lift_quickcheck
              Base_quickcheck.Generator.small_strictly_positive_int
          in
          {lc; up_to= Int up_to; where})
    end

    let run_pre (test : Fuzz.Subject.Test.t) ~(payload : Payload.t) :
        Fuzz.Subject.Test.t Fuzz.State.Monad.t =
      Pd.Counter.declare_and_register payload.lc test

    let control (payload : Payload.t) : Act_fir.Flow_block.For.Simple.t =
      { Fir.Flow_block.For.Simple.lvalue=
          Accessor.construct Fir.Lvalue.variable
            (Common.Litmus_id.variable_name payload.lc.var)
      ; direction= Up Inclusive
      ; init_value= Fir.Expression.int_lit 0
      ; cmp_value= Fir.Expression.constant payload.up_to }

    let wrap (statements : Fuzz.Subject.Statement.t list)
        ~(payload : Payload.t) : Fuzz.Subject.Statement.t =
      let control = control payload in
      let body = Fuzz.Subject.Block.make_generated ~statements () in
      Fir.(
        Accessor.construct Statement.flow
          (Flow_block.for_loop_simple body ~control))
  end)

  module Kv_once : Fuzz.Action_types.S with type Payload.t = Payload.Kv.t =
  Fuzz.Action.Make_surround (struct
    let name = prefix_name Common.Id.("once-kv" @: empty)

    let surround_with : string = "for-loops"

    let readme_suffix : string =
      {| The for loop initialises its
      (fresh) counter to the known value of an existing variable and
      compares it in such a way as to execute only once. |}

    let is_int : Fuzz.Var.Record.t -> bool =
      Fir.Type.Prim.eq ~to_:Int
        Accessor.(
          Fuzz.Var.Record.Access.type_of @> Fir.Type.Access.basic_type
          @> Fir.Type.Basic.Access.prim)

    let var_preds = [Fuzz.Var.Record.has_known_value; is_int]

    (* These may induce atomic loads, and so can't be in atomic blocks. *)
    let path_filter (ctx : Fuzz.Availability.Context.t) =
      Fuzz.Path_filter.(
        live_loop_surround @@ not_in_atomic_block
        @@ Fuzz.Availability.in_thread_with_variables ~predicates:var_preds
             ctx
        @@ empty)

    let available : Fuzz.Availability.t =
      Fuzz.Availability.(
        has_variables ~predicates:var_preds
        + M.(
            lift path_filter >>= is_filter_constructible ~kind:Transform_list))

    module Payload = struct
      include Payload.Kv

      let access_of_var (vrec : Fir.Env.Record.t Common.C_named.t) :
          Fir.Expression.t Fuzz.Payload_gen.t =
        let var =
          Common.C_named.map_right
            ~f:(Accessor_base.get Fir.Env.Record.type_of)
            vrec
        in
        let ty = var.@(Common.C_named.value) in
        (* TODO(@MattWindsor91): is this duplicating something? *)
        Fuzz.Payload_gen.(
          if Fir.Type.is_atomic ty then
            let+ mo = lift_quickcheck Fir.Mem_order.gen_load in
            Fir.Expression.atomic_load
              (Fir.Atomic_load.make
                 ~src:(Fir.Address.on_address_of_typed_id var)
                 ~mo)
          else
            return
              (Fir.Expression.lvalue (Fir.Lvalue.on_value_of_typed_id var)))

      let known_value_val (vrec : Fir.Env.Record.t Common.C_named.t) :
          Fir.Constant.t Fuzz.Payload_gen.t =
        vrec.@?(Common.C_named.value @> Fir.Env.Record.known_value)
        |> Result.of_option
             ~error:
               (Error.of_string "chosen value should have a known value")
        |> Fuzz.Payload_gen.Inner.return

      let known_value_var (scope : Common.Scope.t) :
          Fir.Env.Record.t Common.C_named.t Fuzz.Payload_gen.t =
        (* TODO(@MattWindsor91): this shares a lot of DNA with atomic_store
           redundant. *)
        Fuzz.Payload_gen.(
          let* vs = vars in
          let env =
            Fuzz.Var.Map.env_satisfying_all ~scope vs ~predicates:var_preds
          in
          lift_quickcheck (Fir.Env.gen_random_var_with_record env))

      let counter_type (vrec : Fir.Env.Record.t Common.C_named.t) :
          Fir.Type.t =
        Fir.(
          let prim =
            vrec.@(Common.C_named.value @> Env.Record.type_of
                   @> Type.Access.basic_type @> Type.Basic.Access.prim)
          in
          Type.make
            (Type.Basic.make prim ~is_atomic:false)
            ~is_pointer:false ~is_volatile:false)

      let gen : t Fuzz.Payload_gen.t =
        Fuzz.Payload_gen.(
          let* filter =
            lift (Fn.compose path_filter Context.to_availability)
          in
          let* where = path_with_flags Transform_list ~filter in
          let scope = Common.Scope.Local (Fuzz.Path.tid where.path) in
          let* lc_var = fresh_var scope in
          let* kv_var = known_value_var scope in
          let lc_type = counter_type kv_var in
          let lc : Pd.Counter.t = {var= lc_var; ty= lc_type} in
          let* kv_val = known_value_val kv_var in
          let+ kv_expr = access_of_var kv_var in
          {lc; kv_val; kv_expr; where})
    end

    let run_pre (test : Fuzz.Subject.Test.t) ~(payload : Payload.t) :
        Fuzz.Subject.Test.t Fuzz.State.Monad.t =
      Pd.Counter.declare_and_register payload.lc test

    let wrap (statements : Fuzz.Subject.Statement.t list)
        ~(payload : Payload.t) : Fuzz.Subject.Statement.t =
      let control = Pd.Kv.control Inclusive payload in
      let body = Fuzz.Subject.Block.make_generated ~statements () in
      Fir.(
        Accessor.construct Statement.flow
          (Flow_block.for_loop_simple ~control body))
  end)
end