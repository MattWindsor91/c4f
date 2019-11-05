(* The Automagic Compiler Tormentor

   Copyright (c) 2018--2019 Matt Windsor and contributors

   ACT itself is licensed under the MIT License. See the LICENSE file in the
   project root for more information.

   ACT is based in part on code from the Herdtools7 project
   (https://github.com/herd/herdtools7) : see the LICENSE.herd file in the
   project root for more information. *)

open Core_kernel (* for Blang *)

open Act_common
open Act_utils

(* The unusual module nesting here is to make use of various extensions and
   avoid various shadowings. *)
module Single_passes = struct
  module M = struct
    type t =
      [ `Escape_symbols
      | `Language_hooks
      | `Remove_boundaries
      | `Remove_litmus
      | `Remove_useless
      | `Simplify_deref_chains
      | `Simplify_litmus
      | `Unmangle_symbols
      | `Warn ]
    [@@deriving enum, enumerate]

    let table =
      [ (`Escape_symbols, "escape-symbols")
      ; (`Language_hooks, "language-hooks")
      ; (`Remove_boundaries, "remove-boundaries")
      ; (`Remove_litmus, "remove-litmus")
      ; (`Remove_useless, "remove-useless")
      ; (`Simplify_deref_chains, "simplify-deref-chains")
      ; (`Simplify_litmus, "simplify-litmus")
      ; (`Unmangle_symbols, "unmangle-symbols")
      ; (`Warn, "warn") ]
  end

  include M
  include Enum.Extend_table (M)

  let tree_docs : Property.Tree_doc.t =
    [ ( "escape-symbols"
      , { args= []
        ; details= {| Mangle symbols to ensure litmus tools can lex them. |}
        } )
    ; ( "language-hooks"
      , { args= []
        ; details=
            {| Run language-specific hooks.
             Said hooks may be further categorised into passes, so
             enabling language-hooks on its own won't enable all
             language-specific passes. |}
        } )
    ; ( "remove-boundaries"
      , { args= []
        ; details=
            {| Remove program boundaries.
             If this pass isn't active, program boundaries are retained
             even if they're not jumped to. |}
        } )
    ; ( "remove-litmus"
      , { args= []
        ; details=
            {| Remove elements that have an effect in the assembly, but
             said effect isn't captured in the litmus test. |}
        } )
    ; ( "remove-useless"
      , { args= []
        ; details=
            {| Remove elements with no (direct) effect in the assembly. |} }
      )
    ; ( "simplify-deref-chains"
      , { args= []
        ; details=
            {| Replace 'deref chains' with direct movements.  This is a
             fairly heavyweight change. |}
        } )
    ; ( "simplify-litmus"
      , { args= []
        ; details=
            {| Perform relatively minor simplifications on elements that
             aren't directly understandable by litmus tools. |}
        } )
    ; ( "unmangle-symbols"
      , { args= []
        ; details=
            {| Where possible, replace symbols with their original C
            identifiers. |}
        } )
    ; ( "warn"
      , { args= []
        ; details= {| Warn about things the sanitiser doesn't understand. |}
        } ) ]
end

include Single_passes

let%expect_test "all passes accounted for" =
  Fmt.(pr "@[<v>%a@]@." (list ~sep:cut pp)) (all_list ()) ;
  [%expect
    {|
    escape-symbols
    language-hooks
    remove-boundaries
    remove-litmus
    remove-useless
    simplify-deref-chains
    simplify-litmus
    unmangle-symbols
    warn |}]

let all_lazy = lazy (all_set ())

let explain = Set.of_list (module Single_passes) [`Remove_useless]

let light =
  Set.of_list
    (module Single_passes)
    [`Remove_useless; `Remove_boundaries; `Unmangle_symbols; `Warn]

let standard = all_set ()

module Selector = struct
  type elt = Single_passes.t [@@deriving equal, enumerate]

  module Category = struct
    module M = struct
      type t = [`Standard | `Light | `Explain] [@@deriving enum, enumerate]

      let table =
        [(`Standard, "%standard"); (`Light, "%light"); (`Explain, "%explain")]

      let tree_docs : Property.Tree_doc.t =
        [ ( "%standard"
          , { args= []
            ; details=
                {| Set containing all sanitiser passes that are considered
                 unlikely to change program semantics. |}
            } )
        ; ( "%light"
          , { args= []
            ; details=
                {| Set containing sanitiser passes clean up the assembly,
                 but don't perform semantics-changing removals or simplifications. |}
            } )
        ; ( "%explain"
          , { args= []
            ; details=
                {| Set containing only sanitiser passes that aid readability
                 when reading assembly, for example directive removal. |}
            } ) ]
    end

    include M
    include Enum.Extend_table (M)

    let __t_of_sexp__ = t_of_sexp (* ?! *)

    let%expect_test "all categories accounted for" =
      Fmt.(pr "@[<v>%a@]@." (list ~sep:cut pp) (all_list ())) ;
      [%expect {|
        %standard
        %light
        %explain |}]
  end

  module M = struct
    type t = [elt | Category.t | `Default] [@@deriving equal, enumerate]

    let table =
      List.concat
        [ List.map ~f:(fun (k, v) -> ((k :> t), v)) Single_passes.table
        ; List.map ~f:(fun (k, v) -> ((k :> t), v)) Category.table
        ; [(`Default, "%default")] ]
  end

  include M

  include Enum.Extend_table (struct
    include M
    include Enum.Make_from_enumerate (M)
  end)

  let names = lazy (List.map ~f:snd table)

  let __t_of_sexp__ = t_of_sexp (* ?! *)

  let eval (default : Set.M(Single_passes).t) : t -> Set.M(Single_passes).t =
    function
    | #elt as pass ->
        Set.singleton (module Single_passes) pass
    | `Standard ->
        standard
    | `Explain ->
        explain
    | `Light ->
        light
    | `Default ->
        default

  let tree_docs : Property.Tree_doc.t =
    List.concat
      [ Single_passes.tree_docs
      ; Category.tree_docs
      ; [ ( "%default"
          , { args= []
            ; details=
                {| Set containing whichever sanitiser passes are the
                 default for the particular act subcommand. |}
            } ) ] ]

  let%expect_test "all passes have documentation" =
    let num_passes =
      all |> List.map ~f:to_string
      |> List.map ~f:(List.Assoc.mem tree_docs ~equal:String.Caseless.equal)
      |> List.count ~f:not
    in
    Fmt.pr "@[<v>%d@]@." num_passes ;
    [%expect {| 0 |}]

  let pp_tree : unit Fmt.t =
    Property.Tree_doc.pp tree_docs (List.map ~f:snd table)

  let eval_b (pred : t Blang.t) ~(default : Set.M(Single_passes).t) :
      Set.M(Single_passes).t =
    Blang.eval_set ~universe:all_lazy (eval default) pred

  let%expect_test "eval_b: standard and not explain" =
    let blang = Blang.O.(base `Standard && not (base `Explain)) in
    Stdio.print_s
      [%sexp
        ( eval_b blang ~default:(Set.empty (module Single_passes))
          : Set.M(Single_passes).t )] ;
    [%expect
      {|
      (escape-symbols language-hooks remove-boundaries remove-litmus
       simplify-deref-chains simplify-litmus unmangle-symbols warn) |}]
end
