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

(* Define this in a separate module so we can include it as
   [Elt] below. *)
module M = struct
  (* For some reason, [eq]'s [@equal] override doesn't work,
     and [equal] in ppx_compare hasn't stabilised yet, so we have
     to do this dance to implement error equality. *)
  type err = Error.t
  let equal_err = My_fn.on Error.sexp_of_t Sexp.equal
  let err_of_sexp = Error.t_of_sexp
  let sexp_of_err = Error.sexp_of_t

  type t =
    | Int of int
    | Location of Abstract_location.t
    | Symbol of Abstract_symbol.t
    | Erroneous of err
    | Other
    | Unknown
  [@@deriving sexp, eq]
  ;;

  let pp f = function
    | Int k        -> Format.fprintf f "@[<h>$%d@]" k
    | Erroneous e  -> Format.fprintf f "@[<h><ERR: %a>@]" Error.pp e
    | Location loc -> Abstract_location.pp f loc
    | Symbol s     -> Format.fprintf f "@[<h>sym:%s@]" s
    | Other        -> String.pp f "other"
    | Unknown      -> String.pp f "??"
  ;;
end
include M

module Kind = struct
  module M = struct
    type t =
    | Int
    | Location
    | Symbol
    | Erroneous
    | Other
    | Unknown
  [@@deriving enum, sexp]
    ;;

    let table =
      [ Int      , "none"
      ; Location , "location"
      ; Symbol   , "symbol"
      ; Erroneous, "erroneous"
      ; Other    , "other"
      ; Unknown  , "unknown"
      ]
    ;;
  end

  include M
  include Enum.Extend_table (M)
end
let kind = function
    | Int       _ -> Kind.Int
    | Location  _ -> Location
    | Symbol    _ -> Symbol
    | Erroneous _ -> Erroneous
    | Other       -> Other
    | Unknown     -> Unknown
;;

module type S_predicates = sig
  type t
  val is_unknown : t -> bool
  val is_stack_pointer : t -> bool
  val is_immediate_heap_symbol
    : t
    -> symbol_table:Abstract_symbol.Table.t
    -> bool
  ;;
  val is_jump_symbol : t -> bool
  val is_jump_symbol_where
    :  t
    -> f:(Abstract_symbol.t -> bool)
    -> bool
  ;;
end

module Inherit_predicates
    (P : S_predicates) (I : Utils.Inherit.S_partial with type c := P.t)
  : S_predicates with type t := I.t = struct
  open Option

  let is_unknown x = exists ~f:P.is_unknown (I.component_opt x)
  let is_stack_pointer x = exists ~f:P.is_stack_pointer (I.component_opt x)
  let is_immediate_heap_symbol x ~symbol_table =
    exists ~f:(P.is_immediate_heap_symbol ~symbol_table) (I.component_opt x)
  ;;
  let is_jump_symbol x = exists ~f:P.is_jump_symbol (I.component_opt x)
  let is_jump_symbol_where x ~f =
    exists ~f:(P.is_jump_symbol_where ~f) (I.component_opt x)
  ;;
end

module Flag = struct
  module M = struct
    type t =
      [ `Stack_pointer
      | `Jump_symbol
      | `Immediate_heap_symbol
      ]
    [@@deriving enum, enumerate, sexp]
    ;;

    let table =
      [ `Stack_pointer        , "stack pointer"
      ; `Jump_symbol          , "jump symbol"
      ; `Immediate_heap_symbol, "immediate-heap symbol"
      ]
  end

  include M
  include Enum.Extend_table (M)
end

module type S_properties = sig
  type t
  include S_predicates with type t := t

  val flags : t -> Abstract_symbol.Table.t -> Flag.Set.t
end

module Inherit_properties
    (P : S_properties) (I : Utils.Inherit.S with type c := P.t)
  : S_properties with type t := I.t = struct

  module I_with_c = struct
    type c = P.t
    include I
  end
  include Inherit_predicates (P) (Utils.Inherit.Make_partial (I_with_c))

  let flags x symbol_table = P.flags (I.component x) symbol_table
end

module Properties : S_properties with type t := t = struct
  let is_unknown = function
    | Unknown -> true
    | Erroneous _ | Int _ | Location _ | Symbol _ | Other -> false
  ;;

  let is_stack_pointer = function
    | Location (Abstract_location.StackPointer) -> true
    | Location _
    | Erroneous _ | Int _ | Symbol _ | Other | Unknown -> false
  ;;

  let is_immediate_heap_symbol o ~symbol_table = match o with
    | Symbol sym ->
      Abstract_symbol.(Table.mem symbol_table ~sort:Sort.Heap sym)
    | Erroneous _ | Int _ | Location _ | Other | Unknown -> false
  ;;

  let is_jump_symbol_where o ~f = match o with
    | Symbol sym
    | Location (Abstract_location.Heap sym) -> f sym
    | Location _
    | Erroneous _ | Int _ | Other | Unknown -> false
  ;;

  let is_jump_symbol = is_jump_symbol_where ~f:(Fn.const true)

  let flags o symbol_table =
    [ is_jump_symbol o, `Jump_symbol
    ; is_immediate_heap_symbol o ~symbol_table, `Immediate_heap_symbol
    ; is_stack_pointer o, `Stack_pointer
    ]
    |> List.filter_map ~f:(Tuple2.uncurry Option.some_if)
    |> Flag.Set.of_list
  ;;
end
include Properties

module Bundle = struct
  type elt = M.t

  type t =
    | None
    | Single of M.t
    | Double of M.t * M.t
    | Src_dst of (M.t, M.t) Src_dst.t
  [@@deriving sexp, variants]
  ;;

  (* Intentionally override the [variants] version. *)
  let src_dst ~src ~dst = Src_dst { Src_dst.src; dst }

  module Kind = struct
    module M = struct
      type t =
        | None
        | Single
        | Double
        | Src_dst
      [@@deriving enum, sexp]
      ;;

      let table =
        [ None   , "none"
        ; Single , "single"
        ; Double , "double"
        ; Src_dst, "src-dst"
        ]
      ;;
    end

    include M
    include Enum.Extend_table (M)
  end
  let kind = function
    | None      -> Kind.None
    | Single  _ -> Single
    | Double  _ -> Double
    | Src_dst _ -> Src_dst
  ;;

  include Fold_map.Make_container0 (struct
      module Elt = M
      type nonrec t = t

      module On_monad (Mo : Monad.S) = struct
        module H = Fold_map.Helpers (Mo)

        let fold_mapM ~f ~init bundle =
          Variants.map bundle
            ~none:(H.proc_variant0 H.fold_nop init)
            ~single:(H.proc_variant1 f init)
            ~double:(H.proc_variant2
                       (fun i (x, y) ->
                          let open Mo.Let_syntax in
                          let%bind i' , x' = f i  x in
                          let%map  i'', y' = f i' y in
                          (i'', (x', y')))
                       init)
            ~src_dst:(H.proc_variant1
                        (fun i { Src_dst.src; dst } ->
                           let open Mo.Let_syntax in
                           let%bind i' , src' = f i  src in
                           let%map  i'', dst' = f i' dst in
                           (i'', { Src_dst.src = src'; dst = dst' }))
                        init)
        ;;
      end
    end)

  let pp f = function
    | None -> String.pp f "none"
    | Single x -> M.pp f x
    | Double (op1, op2) ->
      Format.fprintf f "@[%a,@ %a@]" M.pp op1 M.pp op2
    | Src_dst { Src_dst.src; dst} ->
      Format.fprintf f "@[%a@ ->@ %a@]" M.pp src M.pp dst
  ;;

  module type S_predicates = sig
    type t
    val is_none : t -> bool
    val is_src_dst : t -> bool
    val is_part_unknown : t -> bool
    val has_stack_pointer : t -> bool
    val has_src_where : t -> f:(elt -> bool) -> bool
    val has_dst_where : t -> f:(elt -> bool) -> bool
    val has_immediate_heap_symbol
      : t
      -> symbol_table:Abstract_symbol.Table.t
      -> bool
    ;;
    val is_single_jump_symbol_where
      :  t
      -> f:(Abstract_symbol.t -> bool)
      -> bool
    ;;
  end

  module Inherit_predicates
      (P : S_predicates) (I : Utils.Inherit.S_partial with type c := P.t)
    : S_predicates with type t := I.t = struct
    open Option

    let is_none x =
      exists ~f:P.is_none (I.component_opt x)
    ;;
    let is_src_dst x =
      exists ~f:P.is_src_dst (I.component_opt x)
    ;;
    let is_part_unknown x =
      exists ~f:P.is_part_unknown (I.component_opt x)
    ;;
    let has_stack_pointer x =
      exists ~f:P.has_stack_pointer (I.component_opt x)
    ;;
    let has_src_where x ~f =
      exists ~f:(P.has_src_where ~f) (I.component_opt x)
    ;;
    let has_dst_where x ~f =
      exists ~f:(P.has_dst_where ~f) (I.component_opt x)
    ;;
    let has_immediate_heap_symbol x ~symbol_table =
      exists ~f:(P.has_immediate_heap_symbol ~symbol_table)
        (I.component_opt x)
    ;;
    let is_single_jump_symbol_where x ~f =
      exists ~f:(P.is_single_jump_symbol_where ~f)
        (I.component_opt x)
    ;;
  end

  module Flag = struct
    module M = struct
      type t =
        [ `On_src  of Flag.t
        | `On_dst  of Flag.t
        | `On_fst  of Flag.t
        | `On_snd  of Flag.t
        | `On_self of Flag.t
        ]
      [@@deriving eq, enumerate, sexp]
      ;;

      let table =
        List.concat_map
          ~f:(fun (flag, str) ->
              [ `On_src flag , str ^ " on source"
              ; `On_dst flag , str ^ " on dest"
              ; `On_fst flag , str ^ " on operand 1"
              ; `On_snd flag , str ^ " on operand 2"
              ; `On_self flag, str
              ])
          Flag.table
      ;;
    end

    (* Necessary because 'enum' doesn't support argumented
       constructors *)
    module M2 = struct
      include M
      include Enum.Make_from_enumerate (M)
    end

    include M2
    include Enum.Extend_table (M2)
  end

  module type S_properties = sig
    type t
    include S_predicates with type t := t

    val errors : t -> Error.t list
    val flags : t -> Abstract_symbol.Table.t -> Flag.Set.t
  end

  module Inherit_properties
      (P : S_properties) (I : Utils.Inherit.S with type c := P.t)
    : S_properties with type t := I.t = struct

    module I_with_c = struct
      type c = P.t
      include I
    end
    include Inherit_predicates (P) (Utils.Inherit.Make_partial (I_with_c))

    let errors x = P.errors (I.component x)
    let flags x symbol_table = P.flags (I.component x) symbol_table
  end

  module Properties : S_properties with type t := t = struct
    let is_none = function
      | None -> true
      | Src_dst _ | Single _ | Double _ -> false
    ;;

    let is_src_dst = function
      | Src_dst _ -> true
      | None | Single _ | Double _ -> false
    ;;

    let is_part_unknown = exists ~f:is_unknown
    let has_stack_pointer = exists ~f:is_stack_pointer

    let has_src_where operands ~f = match operands with
      | Src_dst { Src_dst.src; _ } -> f src
      | None | Single _ | Double _ -> false
    ;;

    let%expect_test "has_src_where is_stack_pointer: positive" =
      Utils.Io.print_bool
        (has_src_where ~f:is_stack_pointer
           (src_dst
              ~dst:(Location (Abstract_location.GeneralRegister))
              ~src:(Location (Abstract_location.StackPointer))));
      [%expect {| true |}]
    ;;

    let%expect_test "has_src_where is_stack_pointer: negative" =
      Utils.Io.print_bool
        (has_src_where ~f:is_stack_pointer
           (src_dst
              ~src:(Location (Abstract_location.GeneralRegister))
              ~dst:(Location (Abstract_location.StackPointer))));
      [%expect {| false |}]
    ;;

    let has_dst_where operands ~f = match operands with
      | Src_dst { Src_dst.dst; _ } -> f dst
      | None | Single _ | Double _ -> false
    ;;

    let%expect_test "has_dst_where is_stack_pointer: positive" =
      Utils.Io.print_bool
        (has_dst_where ~f:is_stack_pointer
           (src_dst
              ~src:(Location (Abstract_location.GeneralRegister))
              ~dst:(Location (Abstract_location.StackPointer))));
      [%expect {| true |}]
    ;;

    let%expect_test "has_dst_where is_stack_pointer: negative" =
      Utils.Io.print_bool
        (has_dst_where ~f:is_stack_pointer
           (src_dst
              ~dst:(Location (Abstract_location.GeneralRegister))
              ~src:(Location (Abstract_location.StackPointer))));
      [%expect {| false |}]
    ;;

    let has_immediate_heap_symbol operands ~symbol_table =
      exists ~f:(is_immediate_heap_symbol ~symbol_table) operands
    ;;

    let%expect_test "has_immediate_heap_symbol: src/dst positive" =
      let symbol_table = Abstract_symbol.(
          Table.of_sets
            [ Set.of_list [ "foo"; "bar"; "baz" ], Sort.Heap
            ; Set.of_list [ "froz" ], Sort.Label
            ]
        )
      in
      let result = has_immediate_heap_symbol ~symbol_table
          (Src_dst
             { src = Symbol "foo"
             ; dst = Location GeneralRegister
             })
      in
      Sexp.output_hum Out_channel.stdout [%sexp (result : bool)];
      [%expect {| true |}]
    ;;

    let%expect_test "has_immediate_heap_symbol: src/dst negative" =
      let symbol_table = Abstract_symbol.(
          Table.of_sets
            [ Set.of_list [ "foo"; "bar"; "baz" ], Sort.Heap
            ; Set.of_list [ "froz" ], Sort.Label
            ]
        )
      in
      let result = has_immediate_heap_symbol ~symbol_table
          (Src_dst
             { src = Symbol "froz"
             ; dst = Location GeneralRegister
             })
      in
      Sexp.output_hum Out_channel.stdout [%sexp (result : bool)];
      [%expect {| false |}]
    ;;

    let is_single_jump_symbol_where operands ~f =
      match operands with
      | Single o -> is_jump_symbol_where o ~f
      | None | Src_dst _ | Double _ -> false
    ;;

    let errors bundle =
      let f = function
        | Erroneous e -> Some e
        | Int _ | Symbol _ | Location _ | Unknown | Other -> None
      in bundle |> to_list |> List.filter_map ~f
    ;;

    let flags operands symbol_table =
      Flag.Set.(
        match operands with
        | None -> empty
        | Single o ->
          map ~f:(fun x -> `On_self x) (flags o symbol_table)
        | Double (o1, o2) ->
          union
            (map ~f:(fun x -> `On_fst x) (flags o1 symbol_table))
            (map ~f:(fun x -> `On_snd x) (flags o2 symbol_table))
        | Src_dst {src; dst} ->
          union
            (map ~f:(fun x -> `On_src x) (flags src symbol_table))
            (map ~f:(fun x -> `On_dst x) (flags dst symbol_table))
      )
  end

  include Properties
end