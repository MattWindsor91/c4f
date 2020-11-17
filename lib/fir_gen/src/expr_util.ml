(* The Automagic Compiler Tormentor

   Copyright (c) 2018, 2019, 2020 Matt Windsor and contributors

   ACT itself is licensed under the MIT License. See the LICENSE file in the
   project root for more information.

   ACT is based in part on code from the Herdtools7 project
   (https://github.com/herd/herdtools7) : see the LICENSE.herd file in the
   project root for more information. *)

open Base
open Import

let has_ints (env : Fir.Env.t) ~(is_atomic : bool) : bool =
  Fir.Env.has_vars_of_basic_type env
    ~basic:(Fir.Type.Basic.int ~is_atomic ())

let has_bools (env : Fir.Env.t) ~(is_atomic : bool) : bool =
  Fir.Env.has_vars_of_basic_type env
    ~basic:(Fir.Type.Basic.bool ~is_atomic ())

let with_record (g : 'a Q.Generator.t) ~(to_var : 'a -> Act_common.C_id.t)
    ~(env : Fir.Env.t) : ('a * Fir.Env.Record.t) Q.Generator.t =
  Q.Generator.filter_map g ~f:(fun x ->
      Option.(x |> to_var |> Map.find env >>| fun r -> (x, r)))

let lift_loadlike (g : 'a Q.Generator.t) ~(to_expr : 'a -> Fir.Expression.t)
    ~(to_var : 'a -> Common.C_id.t) ~(env : Fir.Env.t) :
    (Fir.Expression.t * Fir.Env.Record.t) Q.Generator.t =
  Q.Generator.map
    ~f:(fun (l, r) -> (to_expr l, r))
    (with_record g ~to_var ~env)

let gen_kv_refl (type v a)
    ~(gen_op : v -> Fir.Expression.t -> a Q.Generator.t)
    ~(gen_load : (v * Fir.Env.Record.t) Q.Generator.t) : a Q.Generator.t =
  Q.Generator.Let_syntax.(
    let%bind v, kv =
      Q.Generator.filter_map gen_load ~f:(fun (l, r) ->
          Option.Let_syntax.(
            let%map kv = Accessor.get_option Fir.Env.Record.known_value r in
            (l, Fir.Expression.constant kv)))
    in
    gen_op v kv)