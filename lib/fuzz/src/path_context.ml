(* The Automagic Compiler Tormentor

   Copyright (c) 2018, 2019, 2020 Matt Windsor and contributors

   ACT itself is licensed under the MIT License. See the LICENSE file in the
   project root for more information.

   ACT is based in part on code from the Herdtools7 project
   (https://github.com/herd/herdtools7) : see the LICENSE.herd file in the
   project root for more information. *)

open Base
open Import

type 'k t =
  { kind: 'k
  ; last_block: Path_filter.Block.t
  ; flags: Set.M(Path_flag).t
  ; filter: Path_filter.t }
[@@deriving fields]

let init ?(filter : Path_filter.t = Path_filter.zero) (kind : 'k) : 'k t =
  {kind; last_block= Top; flags= Set.empty (module Path_flag); filter}

let add_flags (x : 'k t) (flags : Set.M(Path_flag).t) : 'k t Or_error.t =
  Or_error.Let_syntax.(
    let%map () = Path_filter.check_not x.filter ~flags in
    {x with flags= Set.union x.flags flags})

let set_block_kind (x : 'k t) (kind : Path_filter.Block.t) : 'k t =
  {x with last_block= kind}

let check_anchor (x : 'k t) ~(path : Path.Stms.t) ~(block_len : int) :
    unit Or_error.t =
  Path_filter.check_anchor x.filter ~path ~block_len

let check_filter_req (x : 'k t) : unit Or_error.t =
  Or_error.all_unit
    [ Path_filter.check_req x.filter ~flags:x.flags
    ; Path_filter.check_block x.filter ~block:x.last_block ]

let check_filter_stm (x : 'k t) ~(stm : Subject.Statement.t) :
    unit Or_error.t =
  Path_filter.check_final_statement x.filter ~stm

let check_filter_stms (x : 'k t) ~(stms : Subject.Statement.t list) :
    unit Or_error.t =
  Tx.Or_error.combine_map_unit stms ~f:(fun stm -> check_filter_stm x ~stm)

let check_thread_ok (x : _ t) ~(thread : int) : unit Or_error.t =
  (* TODO(@MattWindsor91): push error into Path_filter? *)
  if Path_filter.is_thread_ok x.filter ~thread then Ok ()
  else
    Or_error.error_s
      [%message "Thread not allowed by filter" ~thread:(thread : int)]

let lift_path (x : 'k t) ~(path : 'p) : 'p Path_flag.Flagged.t =
  Path_flag.Flagged.make path ~flags:x.flags
