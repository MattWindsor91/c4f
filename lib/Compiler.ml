(* This file is part of 'act'.

   Copyright (c) 2018 by Matt Windsor

   Permission is hereby granted, free of charge, to any person
   obtaining a copy of this software and associated documentation
   files (the "Software"), to deal in the Software without
   restriction, including without limitation the rights to use, copy,
   modify, merge, publish, distribute, sublicense, and/or sell copies
   of the Software, and to permit persons to whom the Software is
   furnished to do so, subject to the following conditions:

   The above copyright notice and this permission notice shall be
   included in all copies or substantial portions of the Software.

   THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
   EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
   MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
   NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS
   BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN
   ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN
   CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
   SOFTWARE. *)

open Core
open Utils

include Compiler_intf

module Make_spec (R : Machine.Reference)
  : S_spec with module Mach = R = struct
  module Mach = R

  module M = struct
    type t =
      { enabled : bool [@default true] [@sexp_drop_default]
      ; style   : string
      ; emits   : Id.t
      ; cmd     : string
      ; argv    : string sexp_list
      ; herd    : bool [@default true] [@sexp_drop_default]
      ; machine : Mach.t [@default Mach.default]
      } [@@deriving sexp, fields]

    (* We use a different name for the getter than the one
       [@@deriving fields] infers. *)
    let is_enabled = enabled

    let pp f spec =
      Format.pp_open_vbox f 0;
      if not spec.enabled then Format.fprintf f "-- DISABLED --@,";
      My_format.pp_kv f "Style" String.pp spec.style;
      Format.pp_print_cut f ();
      My_format.pp_kv f "Emits" Id.pp spec.emits;
      Format.pp_print_cut f ();
      My_format.pp_kv f "Command"
        (Format.pp_print_list ~pp_sep:(Format.pp_print_space) String.pp)
        (spec.cmd :: spec.argv);
      Format.pp_print_cut f ();
      My_format.pp_kv f "Machine" Mach.pp spec.machine;
      Format.pp_print_cut f ();
      My_format.pp_kv f "Herd"
        (fun f x -> String.pp f (if x then "yes" else "no")) spec.herd;
      Format.pp_close_box f ()
    ;;

    let pp_summary =
      let facts spec =
        List.concat
          [ if enabled spec then [] else ["(DISABLED)"]
          ; if R.remoteness (machine spec) = `Remote then ["(REMOTE)"] else []
          ]
      in
      Fmt.(using facts (hbox (list ~sep:sp string)))
    ;;
  end

  include M

  module With_id = struct
    include Spec.With_id (M)

    let is_enabled w = M.is_enabled (spec w)
    let style      w = M.style      (spec w)
    let emits      w = M.emits      (spec w)
    let cmd        w = M.cmd        (spec w)
    let argv       w = M.argv       (spec w)
    let herd       w = M.herd       (spec w)
    let machine    w = M.machine    (spec w)
  end

  include Spec.Make (struct
      include M
      module With_id = With_id
    end)

  let create = M.Fields.create
end

module Cfg_spec : S_spec with type Mach.t = Id.t =
  Make_spec (Machine.Id)
;;

module Spec : S_spec with type Mach.t = Machine.Spec.With_id.t =
  Make_spec (Machine.Spec.With_id)
;;

module Property = struct
  type t =
    | Id      of Id.Property.t
    | Machine of Machine.Property.t
  [@@deriving sexp, variants]
  ;;

  let tree_docs : Property.Tree_doc.t =
    [ "id",
      { args = [ "PROPERTY" ]
      ; details =
          {| See 'identifier predicates'. |}
      }
    ; "machine",
      { args = [ "PROPERTY" ]
      ; details =
          {| See 'machine predicates'. |}
      }
    ]
  ;;

  let pp_tree : unit Fmt.t =
    Property.Tree_doc.pp tree_docs
      (List.map ~f:fst Variants.descriptions)
  ;;

  let%expect_test "all properties have documentation" =
    let num_passes =
      Variants.descriptions
      |> List.map ~f:fst
      |> List.map ~f:(List.Assoc.mem tree_docs ~equal:String.Caseless.equal)
      |> List.count ~f:not
    in
    Fmt.pr "@[<v>%d@]@." num_passes;
    [%expect {| 0 |}]
  ;;

  let eval (cspec : Spec.With_id.t) = function
    | Id prop      -> Id.Property.eval (Spec.With_id.id cspec) prop
    | Machine prop -> Machine.Property.eval
                        (module Machine.Spec.With_id)
                        (Spec.With_id.machine cspec)
                        prop
  ;;

  let eval_b cspec expr = Blang.eval expr (eval cspec)
end

module type With_spec = sig
  val cspec : Spec.With_id.t
end

(** [No_hooks] is a [Hooks] implementation that does nothing. *)
module No_hooks : Hooks = struct
  let pre ~(infile : Fpath.t) ~(outfile : Fpath.t) : (string * string) Or_error.t =
    Result.return (Fpath.to_string infile, Fpath.to_string outfile)
  ;;
  let post ~(infile : Fpath.t) ~(outfile : Fpath.t) : unit Or_error.t =
    ignore infile; ignore outfile; Result.ok_unit
  ;;
end

(** [Scp_hooks] is a [Hooks] implementation that copies infile and outfile
    to and from a remote directory. *)
module Scp_hooks (C : sig val ssh: Machine.Ssh.t end) : Hooks = struct
  let remote_name_of (file : Fpath.t) : string =
    (* Assuming that scp always supports unix-style paths *)
    sprintf "%s/%s" (Machine.Ssh.copy_dir C.ssh) (Fpath.basename file)
  ;;

  module Scp = Ssh.Scp (Machine.Ssh.To_config (C))

  let pre ~(infile : Fpath.t) ~(outfile : Fpath.t) : (string * string) Or_error.t =
    let open Or_error.Let_syntax in
    let local = Fpath.to_string infile in
    let remote = remote_name_of infile in
    let%map () = Scp.send ~local ~remote in
    (remote, remote_name_of outfile)
  ;;

  let post ~(infile : Fpath.t) ~(outfile : Fpath.t) : unit Or_error.t =
    ignore infile;
    let remote = remote_name_of outfile in
    let local = Fpath.to_string outfile in
    Scp.receive ~remote ~local
  ;;
end

module type Basic_with_run_info = sig
  include Basic
  include With_spec
  module Runner : Runner.S
  module Hooks : Hooks
end

module Make (B : Basic_with_run_info) : S = struct
  include B

  let cmd = Spec.With_id.cmd B.cspec

  let compile ~infile ~outfile =
    let open Or_error.Let_syntax in
    let%bind (infile', outfile') = B.Hooks.pre ~infile ~outfile in
    let s = Spec.With_id.spec B.cspec in
    let argv =
     B.compile_args
        ~args:(Spec.argv s)
        ~emits:(Spec.emits s) ~infile:infile' ~outfile:outfile'
    in
    let%bind () = B.Runner.run ~prog:cmd argv in
    (* NB: post intentionally gets sent the original filenames. *)
    B.Hooks.post ~infile ~outfile
  ;;

  let test () = B.Runner.run ~prog:cmd B.test_args
end

let runner_from_spec (cspec : Spec.With_id.t) =
  Machine.Spec.With_id.runner (Spec.With_id.machine cspec)
;;

let hooks_from_spec (cspec : Spec.With_id.t) =
  match Machine.Spec.With_id.via (Spec.With_id.machine cspec) with
  | Machine.Via.Local -> (module No_hooks : Hooks)
  | Ssh s -> (module Scp_hooks (struct let ssh = s end) : Hooks)
;;

let from_spec f (cspec : Spec.With_id.t) =
  let open Or_error.Let_syntax in
  let%map (module B : Basic) = f cspec in
  let (module Hooks) = hooks_from_spec cspec in
  let (module Runner) = runner_from_spec cspec in
  (module
    (Make (struct
       let cspec = cspec
       include B
       module Hooks = Hooks
       module Runner = Runner
     end)) : S)
;;
