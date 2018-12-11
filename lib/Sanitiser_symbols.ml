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

open Core_kernel
open Utils

(** Sanitiser passes for global symbol renaming

    This module provides a global sanitiser pass that performs two
    renaming sub-passes on all symbols:

    - [`Unmangle_symbols]: replace compiler-mangled symbols
    with their original C identifiers where doing so is unambiguous;
    - [`Escape_symbols]: replace characters in symbols that are
    difficult for Herd-like programs to parse with less human-readable
    (but more machine-readable) equivalents. *)

let mangler =
  (* We could always just use something like Base36 here, but this
     seems a bit more human-readable. *)
  String.Escaping.escape_gen_exn
    ~escape_char:'Z'
    (* We escape some things that couldn't possibly appear in legal
       x86 assembler, but _might_ be generated during sanitisation. *)
    ~escapeworthy_map:[ '+', 'A' (* Add *)
                      ; ',', 'C' (* Comma *)
                      ; '$', 'D' (* Dollar *)
                      ; '.', 'F' (* Full stop *)
                      ; '-', 'M' (* Minus *)
                      ; '%', 'P' (* Percent *)
                      ; '@', 'T' (* aT *)
                      ; '_', 'U' (* Underscore *)
                      ; 'Z', 'Z' (* Z *)
                      ]
;;
let mangle = Staged.unstage mangler

let%expect_test "mangle: sample" =
  print_string (mangle "_foo$bar.BAZ@lorem-ipsum+dolor,sit%amet");
  [%expect {| ZUfooZDbarZFBAZZZTloremZMipsumZAdolorZCsitZPamet |}]

module Make (B : Sanitiser_base.Basic)
  : Sanitiser_base.S_all
    with module Lang := B.Lang
     and module Ctx := B.Ctx
     and module Program_container := B.Program_container = struct
  include B
  module Ctx_Pcon    = Program_container.On_monad (Ctx)
  module Ctx_List    = My_list.On_monad (Ctx)
  module Ctx_Stm_Sym = Lang.Statement.On_symbols.On_monad (Ctx)

  let over_all_symbols progs ~f =
    (* Nested mapping:
       over symbols in statements in statement lists in programs. *)
    Ctx_Pcon.map_m progs
      ~f:(Ctx_List.map_m ~f:(Ctx_Stm_Sym.map_m ~f))

  (** [escape_and_redirect sym] mangles [sym], either by
      generating and installing a new mangling into
      the redirects table if none already exists; or by
      fetching the existing mangle. *)
  let escape_and_redirect sym =
    let open Ctx.Let_syntax in
    match%bind Ctx.get_redirect sym with
    | Some sym' when not (Lang.Symbol.equal sym sym') ->
      (* There's an existing redirect, so we assume it's a
         mangled version. *)
      Ctx.return sym'
    | Some _ | None ->
      let sym' = Lang.Symbol.On_strings.map ~f:mangle sym in
      Ctx.redirect ~src:sym ~dst:sym' >>| fun () -> sym'
  ;;

  (** [escape_symbols progs] reduces identifiers across a program
      container [progs] into a form that herd can parse. *)
  let escape_symbols = over_all_symbols ~f:escape_and_redirect


  let on_all progs =
    Ctx.(
      progs
      |> (`Escape_symbols |-> escape_symbols)
    )
  ;;
end
