(* This file is part of 'act'.

   Copyright (c) 2018, 2019 by Matt Windsor

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

module With_source = struct
  type 'a t = { item : 'a; source : [ `Existing | `Generated ] }
      [@@deriving fields, make]
end

module Program = struct
  type t =
    { decls : Mini.Initialiser.t Mini.id_assoc
    ; stms  : (Mini.Statement.t With_source.t) list
    }
  ;;

  module Stm_path : Mini.S_statement_path
    with type stm = Mini.Statement.t
     and type target = Mini.Statement.t With_source.t = struct
    type stm = Mini.Statement.t
    type target = Mini.Statement.t With_source.t

    let lower_stm = With_source.item
    let lift_stm item = With_source.make ~item ~source:`Generated

    let try_gen_insert_stm t =
      Mini.Statement.Path.try_gen_insert_stm (With_source.item t)
    ;;

    let insert_stm path stm { With_source.item; source } =
      Or_error.(
        item |> Mini.Statement.Path.insert_stm path stm >>|
        (fun item' -> With_source.make ~item:item' ~source)
      )
    ;;
  end


  module Stm_list_path : Mini.S_statement_list_path
    with type stm = Mini.Statement.t
     and type target = Mini.Statement.t With_source.t =
    Mini.Make_statement_list_path (Stm_path)
  ;;

  module Path : Mini.S_function_path
    with type stm = Mini.Statement.t and type target := t = struct
    type target = t
    type stm = Mini.Statement.t

    let gen_insert_stm ({ stms; _ } : target)
      : Mini.stm_hole Mini.function_path Quickcheck.Generator.t =
      Quickcheck.Generator.map (Stm_list_path.gen_insert_stm stms)
        ~f:(fun path -> Mini.On_statements path)
    ;;

    let insert_stm
        (path : Mini.stm_hole Mini.function_path)
        (stm : stm) (prog : target) : target Or_error.t =
      let open Or_error.Let_syntax in
      match path with
      | On_statements rest ->
        let%map stms' =
          Stm_list_path.insert_stm rest stm prog.stms
        in { prog with stms = stms' }
    ;;
  end

  let of_function (func : Mini.Function.t) : t =
    { decls = Mini.Function.body_decls func
    ; stms  = List.map (Mini.Function.body_stms func)
          ~f:(fun item -> With_source.make ~item ~source:`Existing)
    }
  ;;

  let try_extract_parameter_type
    ((n, var) : C_identifier.t * Fuzzer_var.Record.t)
    : (C_identifier.t * Mini.Type.t) Or_error.t =
    Or_error.(
      var
      |> Fuzzer_var.Record.ty
      |> Result.of_option
        ~error:(Error.of_string "Internal error: missing global type")
      >>| Tuple2.create n
    )
  ;;

  (** [make_function_parameters vars] creates a uniform function
      parameter list for a C litmus test using the global
      variable records in [vars]. *)
  let make_function_parameters
    (vars : Fuzzer_var.Map.t)
    : Mini.Type.t Mini.id_assoc Or_error.t =
    vars
    |> C_identifier.Map.filter ~f:(Fuzzer_var.Record.is_global)
    |> C_identifier.Map.to_alist
    |> List.map ~f:try_extract_parameter_type
    |> Or_error.combine_errors
  ;;

  (** [to_function prog ~vars ~id] lifts a subject-program [prog]
      with ID [prog_id]
      back into a Litmus function, adding a parameter list generated
      from [vars]. *)
  let to_function
      (prog : t)
      ~(vars : Fuzzer_var.Map.t)
      ~(id : int)
       : Mini.Function.t Mini.named Or_error.t =
    let open Or_error.Let_syntax in
    let name = C_identifier.of_string (sprintf "P%d" id) in
    let%map parameters = make_function_parameters vars in
    let body_stms = List.map prog.stms ~f:With_source.item in
    let func =
      Mini.Function.make
        ~parameters
        ~body_decls:prog.decls
        ~body_stms
        ()
    in (name, func)
  ;;
end

module Test = struct
  type t =
    { init     : Mini.Constant.t Mini.id_assoc
    ; programs : Program.t list
    }
  ;;

  module Path : Mini.S_program_path
    with type stm = Mini.Statement.t
     and type target := t = struct
    type target = t
    type stm = Mini.Statement.t

    let gen_insert_stm (test : target)
      : Mini.stm_hole Mini.program_path Quickcheck.Generator.t =
      let prog_gens =
        List.mapi test.programs
          ~f:(fun index prog ->
              Quickcheck.Generator.map
                (Program.Path.gen_insert_stm prog)
                ~f:(fun rest -> Mini.On_program { index; rest })
            )
      in Quickcheck.Generator.union prog_gens
    ;;

    let insert_stm
        (path : Mini.stm_hole Mini.program_path)
        (stm : stm) (test : target) : target Or_error.t =
      let open Or_error.Let_syntax in
      match path with
      | On_program { index; rest } ->
        let programs = test.programs in
        let%map programs' = Alter_list.replace programs index
            ~f:(fun x -> x |> Program.Path.insert_stm rest stm >>| Option.some)
        in { test with programs = programs' }
    ;;
  end

  let programs_of_litmus (test : Mini_litmus.Ast.Validated.t)
    : Program.t list =
    test
    |> Mini_litmus.Ast.Validated.programs
    |> List.map ~f:(fun (_, p) -> Program.of_function p)
  ;;

  (** [of_litmus test] converts a validated C litmus test [test]
      to the intermediate form used for fuzzing. *)
  let of_litmus (test : Mini_litmus.Ast.Validated.t) : t =
    { init     = Mini_litmus.Ast.Validated.init test
    ; programs = programs_of_litmus test
    }
  ;;

  let programs_to_litmus
      (progs : Program.t list)
      ~(vars : Fuzzer_var.Map.t)
    : Mini_litmus.Lang.Program.t list Or_error.t =
    progs
    |> List.mapi ~f:(fun id -> Program.to_function ~vars ~id)
    |> Or_error.combine_errors
  ;;

  (** [to_litmus ?post subject ~vars ~name] tries to reconstitute a
     validated C litmus test from the subject [subject], attaching the
     name [name] and optional postcondition [post], and using the
     variable map [vars] to reconstitute parameters. It may fail if
     the resulting litmus is invalid---generally, this signifies an
     internal error. *)
  let to_litmus
      ?(post : Mini_litmus.Ast.Post.t option)
      (subject : t)
      ~(vars : Fuzzer_var.Map.t)
      ~(name : string)
    : Mini_litmus.Ast.Validated.t Or_error.t =
    let open Or_error.Let_syntax in
    let%bind programs = programs_to_litmus ~vars subject.programs in
    Mini_litmus.Ast.Validated.make
      ?post
      ~name
      ~init:(subject.init)
      ~programs
      ()
  ;;

  (** [add_var_to_init subject var initial_value] adds [var] to
      [subject]'s init block with the initial value [initial_value]. *)
  let add_var_to_init
      (subject : t)
      (var : C_identifier.t)
      (initial_value : Mini.Constant.t)
    : t =
    { subject with init = (var, initial_value) :: subject.init }
  ;;
end
