(* The Automagic Compiler Tormentor

   Copyright (c) 2018--2019 Matt Windsor and contributors

   ACT itself is licensed under the MIT License. See the LICENSE file in the
   project root for more information.

   ACT is based in part on code from the Herdtools7 project
   (https://github.com/herd/herdtools7) : see the LICENSE.herd file in the
   project root for more information. *)

open Base

module Result = struct
  type 'a t = {truth: bool; witnesses: 'a list; counter_examples: 'a list}
  [@@deriving fields, yojson]
end

let eval_bop : Predicate.Bop.t -> bool -> bool -> bool = function
  | Or -> (
      || )
  | And -> (
      && )

let eval_pred (pred : 'const Predicate.t)
    ~(elt : 'const Predicate.Element.t -> bool) : bool =
  Predicate.reduce ~elt ~bop:eval_bop pred

let eval_quantifier (quant : Postcondition.Quantifier.t) ~(f : 'a -> bool)
    ~(subjects : 'a list) : 'a Result.t =
  let witnesses, counter_examples = List.partition_tf subjects ~f in
  let truth =
    match quant with
    | Exists ->
        not (List.is_empty witnesses)
    | For_all ->
        List.is_empty counter_examples
  in
  Result.Fields.create ~truth ~witnesses ~counter_examples

let eval (pc : 'const Postcondition.t)
    ~(elt : 'a -> 'const Predicate.Element.t -> bool) ~(subjects : 'a list)
    : 'a Result.t =
  let predicate = Postcondition.predicate pc in
  let quantifier = Postcondition.quantifier pc in
  eval_quantifier quantifier ~subjects ~f:(fun a ->
      eval_pred predicate ~elt:(elt a))
