(* The Automagic Compiler Tormentor

   Copyright (c) 2018--2019 Matt Windsor and contributors

   ACT itself is licensed under the MIT License. See the LICENSE file in the
   project root for more information.

   ACT is based in part on code from the Herdtools7 project
   (https://github.com/herd/herdtools7) : see the LICENSE.herd file in the
   project root for more information. *)

open Base

module Make (B : sig
  module Constant : Act_language.Constant_intf.S

  module Symbol : Act_language.Symbol_intf.S
end) =
struct
  let transform_constant (c : Act_c.Mini.Constant.t) :
      B.Constant.t Or_error.t =
    Or_error.(c |> Act_c.Mini.Constant.to_int >>| B.Constant.of_int)

  let transform_id (id : Act_common.C_id.t)
      ~(redirect_map : B.Symbol.R_map.t) : Act_common.C_id.t Or_error.t =
    B.Symbol.R_map.dest_of_id redirect_map id

  let of_delitmus_aux (dl_aux : Act_delitmus.Aux.t)
      ~(redirect_map : B.Symbol.R_map.t) :
      B.Constant.t Act_litmus.Aux.t Or_error.t =
    let c_litmus_aux = Act_delitmus.Aux.litmus_aux dl_aux in
    (* TODO(@MattWindsor91): use the delitmus map to transform all *LITMUS*
       IDs in the postcondition. *)
    Act_litmus.Aux.With_errors.bi_map_m c_litmus_aux
      ~left:(transform_id ~redirect_map)
      ~right:transform_constant
end
