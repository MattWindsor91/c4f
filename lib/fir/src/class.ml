(* The Automagic Compiler Tormentor

   Copyright (c) 2018--2020 Matt Windsor and contributors

   ACT itself is licensed under the MIT License. See the LICENSE file in the
   project root for more information.

   ACT is based in part on code from the Herdtools7 project
   (https://github.com/herd/herdtools7) : see the LICENSE.herd file in the
   project root for more information. *)

open Base

module Make_ext (B : Class_types.S) :
  Class_types.S_ext with type t := B.t and type 'meta elt := 'meta B.elt =
struct
  let class_matches_any (clazz : B.t) ~(templates : B.t list) : bool =
    List.exists templates ~f:(fun template ->
        B.class_matches clazz ~template )

  let class_unmatches_any (clazz : B.t) ~(templates : B.t list) : bool =
    List.exists templates ~f:(fun template ->
        not (B.class_matches clazz ~template) )

  let matches_any (type e) (stm : e B.elt) ~(templates : B.t list) : bool =
    Option.exists (B.classify stm) ~f:(class_matches_any ~templates)

  let unmatches_any (type e) (stm : e B.elt) ~(templates : B.t list) : bool =
    Option.for_all (B.classify stm) ~f:(class_unmatches_any ~templates)

  let count_rec_matches (type e) (stm : e B.elt) ~(templates : B.t list) :
      int =
    List.count (B.classify_rec stm) ~f:(class_matches_any ~templates)

  let rec_matches_any (type e) (stm : e B.elt) ~(templates : B.t list) : bool
      =
    List.exists (B.classify_rec stm) ~f:(class_matches_any ~templates)

  let rec_unmatches_any (type e) (stm : e B.elt) ~(templates : B.t list) :
      bool =
    List.exists (B.classify_rec stm) ~f:(class_unmatches_any ~templates)
end

let lift_classify_rec (type m t) (f : m -> t option) (x : m) : t list =
  Option.to_list (f x)
