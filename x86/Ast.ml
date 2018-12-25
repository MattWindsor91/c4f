(*
This file is part of 'act'.

Copyright (c) 2018 by Matt Windsor
   (parts (c) 2010-2018 Institut National de Recherche en Informatique et
en Automatique, Jade Alglave, and Luc Maranget)

Permission is hereby granted, free of charge, to any person obtaining
a copy of this software and associated documentation files (the
"Software"), to deal in the Software without restriction, including
without limitation the rights to use, copy, modify, merge, publish,
distribute, sublicense, and/or sell copies of the Software, and to
permit persons to whom the Software is furnished to do so, subject to
the following conditions:

The above copyright notice and this permission notice shall be
included in all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE
LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION
OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION
WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

This file derives from the Herd7 project
(https://github.com/herd/herdtools7); its original attribution and
copyright notice follow. *)

(****************************************************************************)
(*                           the diy toolsuite                              *)
(*                                                                          *)
(* Jade Alglave, University College London, UK.                             *)
(* Luc Maranget, INRIA Paris-Rocquencourt, France.                          *)
(*                                                                          *)
(* Copyright 2010-present Institut National de Recherche en Informatique et *)
(* en Automatique and the authors. All rights reserved.                     *)
(*                                                                          *)
(* This software is governed by the CeCILL-B license under French law and   *)
(* abiding by the rules of distribution of free software. You can use,      *)
(* modify and/ or redistribute the software under the terms of the CeCILL-B *)
(* license as circulated by CEA, CNRS and INRIA at the following URL        *)
(* "http://www.cecill.info". We also give a copy in LICENSE.txt.            *)
(****************************************************************************)

open Core_kernel
open Utils
open Travesty

module Reg = struct
  module M = struct
    type gp8h =
      [ `AH | `BH | `CH | `DH ]
    [@@deriving enumerate, eq, sexp]
    ;;

    type gp8l =
      [ `AL | `BL | `CL | `DL ]
    [@@deriving enumerate, eq, sexp]
    ;;

    type gp8 =
      [ gp8h | gp8l ]
    [@@deriving enumerate, eq, sexp]
    ;;

    type gp16 =
      [ `AX | `BX | `CX | `DX ]
    [@@deriving enumerate, eq, sexp]
    ;;

    type gp32 =
      [ `EAX | `EBX | `ECX | `EDX ]
    [@@deriving enumerate, eq, sexp]
    ;;

    type gp =
      [ gp8 | gp16 | gp32 ]
    [@@deriving enumerate, eq, sexp]
    ;;

    type seg =
      [ `CS | `DS | `SS | `ES | `FS | `GS ]
    [@@deriving enumerate, eq, sexp]
    ;;

    type flag =
      [ `CF | `PF | `AF | `ZF | `SF | `OF ]
    [@@deriving enumerate, eq, sexp]
    ;;

    type sp16 =
      [ seg | `BP | `SP | `SI | `DI ]
    [@@deriving enumerate, eq, sexp]
    ;;

    type sp32 =
      [ `EIP | `EBP | `ESP | `ESI | `EDI ]
    [@@deriving enumerate, eq, sexp]
    ;;

    type sp =
      [ sp16 | sp32 ]
    [@@deriving enumerate, eq, sexp]
    ;;

    type reg8 = gp8

    type reg16 =
      [ gp16 | sp16 ]
    [@@deriving enumerate, eq, sexp]
    ;;

    type reg32 =
      [ gp32 | sp32 ]
    [@@deriving enumerate, eq, sexp]
    ;;

    type t =
      [ gp8 (* can't use reg8 here, it breaks sexp *)
      | reg16
      | reg32
      | flag
      ]
    [@@deriving enumerate, eq, sexp]
    ;;

    let table : (t, string) List.Assoc.t =
      [ `AH , "AH"
      ; `AL , "AL"
      ; `AX , "AX"
      ; `EAX, "EAX"
      ; `BH , "BH"
      ; `BL , "BL"
      ; `BX , "BX"
      ; `EBX, "EBX"
      ; `CH , "CH"
      ; `CL , "CL"
      ; `CX , "CX"
      ; `ECX, "ECX"
      ; `DH , "DH"
      ; `DL , "DL"
      ; `DX , "DX"
      ; `EDX, "EDX"
      ; `BP , "BP"
      ; `EBP, "EBP"
      ; `SI , "SI"
      ; `ESI, "ESI"
      ; `DI , "DI"
      ; `EDI, "EDI"
      ; `SP , "SP"
      ; `ESP, "ESP"
      ; `CS , "CS"
      ; `DS , "DS"
      ; `SS , "SS"
      ; `ES , "ES"
      ; `FS , "FS"
      ; `GS , "GS"
      ; `CF , "CF"
      ; `PF , "PF"
      ; `AF , "AF"
      ; `ZF , "ZF"
      ; `SF , "SF"
      ; `OF , "OF"
      ; `EIP, "EIP"
      ]
    ;;
  end

  include M
  include Enum.Extend_table (struct
      include M
      include Enum.Make_from_enumerate (M)
    end)
  ;;
end

module Disp = struct
  type t =
    | Symbolic of string
    | Numeric of int
  [@@deriving sexp, variants, eq]

  (** Base mapper for displacements *)
  module Base_map (M : Monad.S) = struct
    module F = Traversable.Helpers (M)

    let map_m (x : t) ~symbolic ~numeric : t M.t =
      Variants.map x
        ~symbolic:(F.proc_variant1 symbolic)
        ~numeric:(F.proc_variant1 numeric)
    ;;
  end

  module On_symbols : Traversable.S0_container with type t := t
                                                and type Elt.t = string =
    Traversable.Make_container0 (struct
      type nonrec t = t
      module Elt = String

      module On_monad (M : Monad.S) = struct
        module B = Base_map (M)
        module F = Traversable.Helpers (M)

        let map_m t ~f =
          B.map_m t
            ~symbolic:f
            (* Numeric displacements, of course, have no symbols *)
            ~numeric:M.return
        ;;
      end
    end)
end

module Index = struct
  type t =
    | Unscaled of Reg.t
    | Scaled of Reg.t * int
  [@@deriving sexp, variants, eq]

  (** Base mapper for indices *)
  module Base_map (M : Monad.S) = struct
    module F = Traversable.Helpers (M)

    let map_m (x : t) ~unscaled ~scaled : t M.t =
      Variants.map x
        ~unscaled:(F.proc_variant1 unscaled)
        ~scaled:(F.proc_variant2 scaled)
    ;;
  end

  (** Recursive mapper for registers *)
  module On_registers : Traversable.S0_container with type t := t
                                                  and type Elt.t = Reg.t =
    Traversable.Make_container0 (struct
      type nonrec t = t
      module Elt = Reg

      module On_monad (M : Monad.S) = struct
        module B = Base_map (M)
        module F = Traversable.Helpers (M)

        let map_m t ~f =
          B.map_m t
            ~unscaled:f
            ~scaled:M.(fun (r, k) -> f r >>| (fun r' -> (r', k)))
        ;;
      end
    end)
end

(*
 * Memory addresses
 *)

module Indirect = struct
  type t =
    { seg    : Reg.t   option
    ; disp   : Disp.t  option
    ; base   : Reg.t   option
    ; index  : Index.t option
    }
  [@@deriving sexp, eq, fields, make]

  (** Base mapper for memory addresses *)
  module Base_map (M : Monad.S) = struct
    module F = Traversable.Helpers (M)

    let map_m indirect ~seg ~disp ~base ~index =
      Fields.fold
        ~init:(M.return indirect)
        ~seg:(F.proc_field seg)
        ~disp:(F.proc_field disp)
        ~base:(F.proc_field base)
        ~index:(F.proc_field index)
    ;;
  end

  (** Recursive mapper for symbols *)
  module On_symbols
    : Traversable.S0_container with type t := t
                                and type Elt.t = string =
    Traversable.Make_container0 (struct
      type nonrec t = t
      module Elt = String
      module Set = String.Set

      module On_monad (M : Monad.S) = struct
        module B = Base_map (M)
        module F = Traversable.Helpers (M)

        module D = Disp.On_symbols.On_monad (M)
        module O = T_option.On_monad (M)

        let map_m t ~f =
          B.map_m t
            ~disp:(O.map_m ~f:(D.map_m ~f))
            (* Segments, bases, and indices have no symbols. *)
            ~seg:M.return
            ~base:M.return
            ~index:M.return
        ;;
      end
    end)

  (** Recursive mapper for registers *)
  module On_registers
    : Traversable.S0_container with type t := t and type Elt.t = Reg.t =
    Traversable.Make_container0 (struct
      type nonrec t = t
      module Elt = Reg

      module On_monad (M : Monad.S) = struct
        module B = Base_map (M)
        module F = Traversable.Helpers (M)
        module O = T_option.On_monad (M)
        module I = Index.On_registers.On_monad (M)

        let map_m t ~f =
          B.map_m t
            ~seg:(O.map_m ~f)
            ~base:(O.map_m ~f)
            ~index:(O.map_m ~f:(I.map_m ~f))
            (* Displacements have no registers. *)
            ~disp:M.return
        ;;
      end
    end)
  ;;
end

(*
 * Locations
 *)


module Location = struct
  type t =
    | Indirect of Indirect.t
    | Reg of Reg.t
  [@@deriving sexp, variants, eq]

  (** Base mapper for locations *)
  module Base_map (M : Monad.S) = struct
    module F = Traversable.Helpers (M)

    let map_m x ~indirect ~reg =
      Variants.map
        x
        ~indirect:(F.proc_variant1 indirect)
        ~reg:(F.proc_variant1 reg)
    ;;
  end

  module On_registers
    : Traversable.S0_container with type t := t and type Elt.t = Reg.t =
    Traversable.Make_container0 (struct
      type nonrec t = t
      module Elt = Reg

      module On_monad (M : Monad.S) = struct
        module B = Base_map (M)
        module F = Traversable.Helpers (M)
        module I = Indirect.On_registers.On_monad (M)

        let map_m t ~f = B.map_m t ~indirect:(I.map_m ~f) ~reg:f
      end
    end)
  ;;

  module On_symbols
    : Traversable.S0_container with type t := t and type Elt.t = string =
    Traversable.Make_container0 (struct
      type nonrec t = t
      module Elt = String

      module On_monad (M : Monad.S) = struct
        module B = Base_map (M)
        module F = Traversable.Helpers (M)
        module I = Indirect.On_symbols.On_monad (M)

        let map_m t ~f =
          B.map_m t
            ~indirect:(I.map_m ~f)
            (* Registers don't have any symbols *)
            ~reg:M.return
        ;;
      end
    end)
  ;;
end

module Operand = struct
  type bop =
    | BopPlus
    | BopMinus
  [@@deriving sexp, eq]

  type t =
    | Location of Location.t
    | Immediate of Disp.t
    | String of string
    | Typ of string
    | Bop of t * bop * t
  [@@deriving sexp, variants, eq]

  (** Base mapper for operands *)
  module Base_map (M : Monad.S) = struct
    module F = Traversable.Helpers (M)

    let rec map_m
      (x : t)
        ~location
        ~immediate
        ~string
        ~typ
        ~bop
      : t M.t =
      Variants.map
        x
        ~location:(F.proc_variant1 location)
        ~immediate:(F.proc_variant1 immediate)
        ~string:(F.proc_variant1 string)
        ~typ:(F.proc_variant1 typ)
        ~bop:(F.proc_variant3
                (fun (l, b, r) ->
                   let open M.Let_syntax in
                   let%bind l' = map_m ~location ~immediate ~string ~typ ~bop l in
                   let%bind b' = bop b in
                   let%map  r' = map_m ~location ~immediate ~string ~typ ~bop r in
                   (l', b', r')))
    ;;
  end

  (** Recursive mapper for locations in operands *)
  module On_locations
    : Traversable.S0_container with type t := t and type Elt.t = Location.t =
    Traversable.Make_container0 (struct
      type nonrec t = t
      module Elt = Location

      module On_monad (M : Monad.S) = struct
        module B = Base_map (M)
        module F = Traversable.Helpers (M)

        let map_m t ~f =
          B.map_m t
            ~location:f
            (* These don't contain locations: *)
            ~immediate:M.return
            ~string:M.return
            ~typ:M.return
            ~bop:M.return (* NB: this folds over the operator *)
        ;;
      end
    end)

  (** Recursive mapper for symbols in operands *)
  module On_symbols
    : Traversable.S0_container with type t := t and type Elt.t = string =
    Traversable.Make_container0 (struct
      type nonrec t = t
      module Elt = String

      module On_monad (M : Monad.S) = struct
        module B = Base_map (M)
        module L = Location.On_symbols.On_monad (M)
        module D = Disp.On_symbols.On_monad (M)

        let map_m t ~f =
          B.map_m t
            ~location:(L.map_m ~f)
            ~immediate:(D.map_m ~f)
            (* These don't contain symbols: *)
            ~string:M.return
            ~typ:M.return
            ~bop:M.return (* NB: this folds over the operator *)
        ;;
      end
    end)
  ;;

  let%expect_test "symbol fold over bop" =
    let ast =
      bop
        (bop
           (immediate (Disp.Symbolic "a"))
           BopPlus
           (immediate (Disp.Symbolic "b")))
        BopMinus
        (location
           (Location.Indirect (Indirect.make ~disp:(Disp.Symbolic "c") ())))
    in
    let f count sym = (count + 1), String.capitalize sym in
    let (total, ast') = On_symbols.fold_map ~f ~init:0 ast in
    Format.printf "@[<v>@[<h>Total:@ %d@]@,%a@]@."
      total
      Sexp.pp_hum [%sexp (ast' : t)];
    [%expect {|
      Total: 3
      (Bop (Bop (Immediate (Symbolic A)) BopPlus (Immediate (Symbolic B))) BopMinus
       (Location (Indirect ((seg ()) (disp ((Symbolic C))) (base ()) (index ()))))) |}]
  ;;
end

(*
 * Prefixes
 *)

type prefix =
  | PreLock
[@@deriving sexp, eq]

(*
 * Instructions
 *)

module Instruction = struct
  module T = struct
    type t =
      { prefix   : prefix option
      ; opcode   : Opcode.t
      ; operands : Operand.t list
      }
    [@@deriving sexp, fields, eq, make]
    ;;
  end
  include T

  (** Base mapper for instructions *)
  module Base_map (M : Monad.S) = struct
    module F = Traversable.Helpers (M)

    let map_m ins ~prefix ~opcode ~operands =
      Fields.fold
        ~init:(M.return ins)
        ~prefix:(F.proc_field prefix)
        ~opcode:(F.proc_field opcode)
        ~operands:(F.proc_field operands)
    ;;
  end

  (** Recursive mapper for symbols in instructions *)
  module On_symbols
    : Traversable.S0_container with type t := t and type Elt.t = string =
    Traversable.Make_container0 (struct
      type nonrec t = t
      module Elt = String
      module Set = String.Set

      module On_monad (M : Monad.S) = struct
        module B  = Base_map (M)
        module F  = Traversable.Helpers (M)
        module OS = Operand.On_symbols.On_monad (M)
        module L  = T_list.On_monad (M)

        let map_m t ~f =
          B.map_m t
            ~operands:(L.map_m ~f:(OS.map_m ~f))
            (* Prefixes and opcodes don't contain symbols. *)
            ~prefix:M.return
            ~opcode:M.return
        ;;
      end
    end)
  ;;

  (** Recursive mapper for locations in instructions *)
  module On_locations
    : Traversable.S0_container with type t := t and type Elt.t = Location.t =
    Traversable.Make_container0 (struct
      type nonrec t = t
      module Elt = Location

      module On_monad (M : Monad.S) = struct
        module B  = Base_map (M)
        module F  = Traversable.Helpers (M)
        module OL = Operand.On_locations.On_monad (M)
        module L  = T_list.On_monad (M)

        let map_m t ~f =
          B.map_m t
            ~operands:(L.map_m ~f:(OL.map_m ~f))
            (* Prefixes and opcodes don't contain locations. *)
            ~prefix:M.return
            ~opcode:M.return
        ;;
      end
    end)
  ;;
end

module Statement = struct
  type t =
    | Instruction of Instruction.t
    | Label of string
    | Nop
  [@@deriving sexp, eq, variants]

  (** Base mapper for statements *)
  module Base_map (M : Monad.S) = struct
    module F = Traversable.Helpers (M)

    let map_m x ~instruction ~label ~nop =
      Variants.map x
        ~instruction:(F.proc_variant1 instruction)
        ~label:(F.proc_variant1 label)
        ~nop:(F.proc_variant0 nop)
    ;;
  end

  (** Recursive mapper for instructions in statements *)
  module On_instructions
    : Traversable.S0_container with type t := t
                           and type Elt.t = Instruction.t =
    Traversable.Make_container0 (struct
      type nonrec t = t
      module Elt = Instruction

      module On_monad (M : Monad.S) = struct
        module B = Base_map (M)
        module F = Traversable.Helpers (M)
        module I = Instruction.On_symbols.On_monad (M)

        let map_m t ~f =
          B.map_m t
            ~instruction:f
            (* These don't contain instructions: *)
            ~label:M.return
            ~nop:M.return
        ;;
      end
    end)

  (** Recursive mapper for symbols in statements *)
  module On_symbols
    : Traversable.S0_container with type t := t and type Elt.t = string =
    Traversable.Make_container0 (struct
      type nonrec t = t
      module Elt = String

      module On_monad (M : Monad.S) = struct
        module B = Base_map (M)
        module F = Traversable.Helpers (M)
        module I = Instruction.On_symbols.On_monad (M)

        let map_m t ~f =
          B.map_m t
            ~instruction:(I.map_m ~f)
            ~label:f
            (* These don't contain symbols: *)
            ~nop:M.return
        ;;
      end
    end)
end

(** [t] is the type of an X86 abstract syntax tree, containing the
    specific X86 syntax dialect and a list of statements. *)
type t =
  { syntax  : Dialect.t
  ; program : Statement.t list
  }
[@@deriving sexp, eq, fields]

(** Base mapper for ASTs *)
module Base_map (M : Monad.S) = struct
  module F = Traversable.Helpers (M)

  let map_m x ~syntax ~program =
    Fields.fold
      ~init:(M.return x)
      ~syntax:(F.proc_field syntax)
      ~program:(F.proc_field program)
    ;;
end

module On_listings
  : Traversable.S0_container with type t := t and type Elt.t = Statement.t list =
  Traversable.Make_container0 (struct
    type nonrec t = t
    module Elt = struct type t = Statement.t list [@@deriving eq] end
    module On_monad (M : Monad.S) = struct
      module B = Base_map (M)
      let map_m t ~f = B.map_m t ~program:f ~syntax:M.return
    end
  end)
;;

module On_statements
  : Traversable.S0_container with type t := t and type Elt.t = Statement.t =
  Traversable.Chain0 (struct
    type nonrec t = t
    include On_listings
  end)
    (T_list.With_elt (Statement))
