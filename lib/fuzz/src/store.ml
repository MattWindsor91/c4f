(* This file is part of 'act'.

   Copyright (c) 2018, 2019 by Matt Windsor

   Permission is hereby granted, free of charge, to any person obtaining a
   copy of this software and associated documentation files (the
   "Software"), to deal in the Software without restriction, including
   without limitation the rights to use, copy, modify, merge, publish,
   distribute, sublicense, and/or sell copies of the Software, and to permit
   persons to whom the Software is furnished to do so, subject to the
   following conditions:

   The above copyright notice and this permission notice shall be included
   in all copies or substantial portions of the Software.

   THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS
   OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
   MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN
   NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM,
   DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR
   OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE
   USE OR OTHER DEALINGS IN THE SOFTWARE. *)

open Base
module Ac = Act_common

module Random_state = struct
  (* We don't give [gen] here, because it depends quite a lot on the
     functor arguments of [Make]. *)

  type t =
    { store: Act_c_mini.Atomic_store.t
    ; path: Act_c_mini.Path.stm_hole Act_c_mini.Path.program_path }
  [@@deriving fields, make, sexp_of]
end

module Make (B : sig
  val name : Ac.Id.t

  val default_weight : int

  val forbid_already_written : bool

  module Quickcheck
      (Src : Act_c_mini.Env_types.S)
      (Dst : Act_c_mini.Env_types.S) :
    Act_utils.My_quickcheck.S_with_sexp
      with type t := Act_c_mini.Atomic_store.t
end) : Action_types.S with type Random_state.t = Random_state.t = struct
  let name = B.name

  let default_weight = B.default_weight

  (** [readme_chunks ()] generates fragments of unformatted README text
      based on the configuration of this store module. *)
  let readme_chunks () : (bool * string) list =
    [ ( true
      , {|
       Generates a store operation on a randomly selected fuzzer-generated
       global variable.
       |}
      )
    ; ( B.forbid_already_written
      , {|
       This version of the action only stores to variables that haven't
       previously been selected for store actions.  This makes calculating
       candidate executions easier, but limits the degree of entropy
       somewhat.
       |}
      ) ]

  let select_and_format_chunk (select : bool) (chunk : string) :
      string option =
    if select then Some (Act_utils.My_string.format_for_readme chunk)
    else None

  let readme () =
    readme_chunks ()
    |> List.filter_map ~f:(fun (select, chunk) ->
           select_and_format_chunk select chunk)
    |> String.concat ~sep:"\n\n"

  (** Lists the restrictions we put on source variables. *)
  let src_restrictions : (Var.Record.t -> bool) list Lazy.t = lazy []

  (** Lists the restrictions we put on destination variables. *)
  let dst_restrictions : (Var.Record.t -> bool) list Lazy.t =
    lazy
      Var.Record.(
        [ is_atomic
        ; was_generated
          (* This is to make sure that we don't change the observable
             semantics of the program over its original variables. *)
        ; Fn.non has_dependencies
          (* This action changes the value, so we can't do it to variables
             with depended-upon values. *)
         ]
        @ if B.forbid_already_written then [Fn.non has_writes] else [])

  module Random_state = struct
    type t = Random_state.t [@@deriving sexp_of]

    module G = Base_quickcheck.Generator

    let src_env (vars : Var.Map.t) : (module Act_c_mini.Env_types.S) =
      let predicates = Lazy.force src_restrictions in
      Var.Map.env_module_satisfying_all ~predicates vars

    let dst_env (vars : Var.Map.t) : (module Act_c_mini.Env_types.S) =
      let predicates = Lazy.force dst_restrictions in
      Var.Map.env_module_satisfying_all ~predicates vars

    let error_if_empty (env : string) (module M : Act_c_mini.Env_types.S) :
        unit Or_error.t =
      if Act_common.C_id.Map.is_empty M.env then
        Or_error.error_s
          [%message
            "Internal error: Environment was empty." ~here:[%here] ~env]
      else Result.ok_unit

    let gen_store (o : Ac.Output.t) (vars : Var.Map.t) :
        Act_c_mini.Atomic_store.t G.t Or_error.t =
      let (module Src) = src_env vars in
      let (module Dst) = dst_env vars in
      Ac.Output.pv o "%a: got environments@." Ac.Id.pp name ;
      let open Or_error.Let_syntax in
      let%bind () = error_if_empty "src" (module Src) in
      let%map () = error_if_empty "dst" (module Dst) in
      Ac.Output.pv o "%a: environments are non-empty@." Ac.Id.pp name ;
      Ac.Output.pv o "%a: src environment: @[%a@]@." Ac.Id.pp name
        Sexp.pp_hum
        [%sexp (Src.env : Act_c_mini.Type.t Ac.C_id.Map.t)] ;
      Ac.Output.pv o "%a: dst environment: @[%a@]@." Ac.Id.pp name
        Sexp.pp_hum
        [%sexp (Dst.env : Act_c_mini.Type.t Ac.C_id.Map.t)] ;
      let module Gen = B.Quickcheck (Src) (Dst) in
      Ac.Output.pv o "%a: built generator module@." Ac.Id.pp name ;
      [%quickcheck.generator: Gen.t]

    let gen' (o : Ac.Output.t) (subject : Subject.Test.t) (vars : Var.Map.t)
        : t G.t Or_error.t =
      let open Or_error.Let_syntax in
      Ac.Output.pv o "%a: building generators...@." Ac.Id.pp name ;
      let%map g_store = gen_store o vars in
      Ac.Output.pv o "%a: built store generator@." Ac.Id.pp name ;
      let g_path = Subject.Test.Path.gen_insert_stm subject in
      Ac.Output.pv o "%a: built path generator@." Ac.Id.pp name ;
      G.map2
        ~f:(fun store path -> Random_state.make ~store ~path)
        g_store g_path

    let gen (subject : Subject.Test.t) : t G.t State.Monad.t =
      let open State.Monad.Let_syntax in
      let%bind o = State.Monad.output () in
      State.Monad.with_vars_m
        (Fn.compose State.Monad.Monadic.return (gen' o subject))
  end

  let available _ =
    State.Monad.with_vars
      (Var.Map.exists_satisfying_all
         ~predicates:(Lazy.force dst_restrictions))

  (* This action writes to the destination, so we no longer have a known
     value for it. *)
  let mark_store_dst (store : Act_c_mini.Atomic_store.t) :
      unit State.Monad.t =
    let open State.Monad.Let_syntax in
    let dst = Act_c_mini.Atomic_store.dst store in
    let dst_var = Act_c_mini.Address.variable_of dst in
    let%bind () = State.Monad.erase_var_value dst_var in
    State.Monad.add_write dst_var

  module Exp_idents =
    Act_c_mini.Expression.On_identifiers.On_monad (State.Monad)

  (* This action also introduces dependencies on every variable in the
     source. *)
  let add_dependencies_to_store_src (store : Act_c_mini.Atomic_store.t) :
      unit State.Monad.t =
    Exp_idents.iter_m
      (Act_c_mini.Atomic_store.src store)
      ~f:State.Monad.add_dependency

  let run (subject : Subject.Test.t) ({store; path} : Random_state.t) :
      Subject.Test.t State.Monad.t =
    let open State.Monad.Let_syntax in
    let store_stm = Act_c_mini.Statement.atomic_store store in
    let%bind o = State.Monad.output () in
    Ac.Output.pv o "%a: Erasing known value of store destination@." Ac.Id.pp
      name ;
    let%bind () = mark_store_dst store in
    Ac.Output.pv o "%a: Adding dependency to store source@." Ac.Id.pp name ;
    let%bind () = add_dependencies_to_store_src store in
    State.Monad.Monadic.return
      (Subject.Test.Path.insert_stm path store_stm subject)
end

module Int : Action_types.S with type Random_state.t = Random_state.t =
Make (struct
  let name = Ac.Id.of_string "store.make.int.single"

  let forbid_already_written = true (* for now *)

  let default_weight = 3

  module Quickcheck = Act_c_mini.Atomic_store.Quickcheck_ints
end)
