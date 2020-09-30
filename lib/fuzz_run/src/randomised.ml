(* The Automagic Compiler Tormentor

   Copyright (c) 2018, 2019, 2020 Matt Windsor and contributors

   ACT itself is licensed under the MIT License. See the LICENSE file in the
   project root for more information.

   ACT is based in part on code from the Herdtools7 project
   (https://github.com/herd/herdtools7) : see the LICENSE.herd file in the
   project root for more information. *)

open Base
open Import

(** [make_rng seed] creates a splittable RNG; if [seed] is [Some s], [s] will
    be used as the RNG's seed, otherwise a low-entropy system-derived seed is
    used. *)
let make_rng : int option -> Splittable_random.State.t = function
  | Some seed ->
      Splittable_random.State.of_int seed
  | None ->
      Splittable_random.State.create (Random.State.make_self_init ())

(** Tracks parts of the fuzzer state and environment that we can't keep in
    the inner state monad for various reasons (circular dependencies, being
    specific to how we choose actions, etc). *)
module Runner_state = struct
  type t =
    { pool: Action_pool.t
    ; random: Splittable_random.State.t
    ; trace: Fuzz.Trace.t
    ; params: Fuzz.Param_map.t }
  [@@deriving accessors]

  module Monad = Travesty.State_transform.Make (struct
    type nonrec t = t

    module Inner = Fuzz.State.Monad
  end)

  (* TODO(@MattWindsor91): these should really be available in the monad,
     as maybe a Travesty extension or summat. *)
  let peek_acc acc = Monad.peek (Accessor.get acc)
  let modify_acc acc f = Monad.modify (Accessor.map acc ~f)

  let make_actx (subject : Fuzz.Subject.Test.t) :
      Fuzz.Availability.Context.t Monad.t =
    Monad.(
      peek_acc params
      >>= fun params ->
      Monadic.return
        (Fuzz.State.Monad.peek (fun state ->
             {Fuzz.Availability.Context.state; subject; params})))

  let make_gen_context (action_id : Common.Id.t)
      (subject : Fuzz.Subject.Test.t) : Fuzz.Payload_gen.Context.t Monad.t =
    Monad.(
      Let_syntax.(
        let%bind actx = make_actx subject in
        let%map random = peek (fun x -> x.random) in
        {Fuzz.Payload_gen.Context.action_id; random; actx}))

  let return_err (x : 'a Or_error.t) : 'a Monad.t =
    Monad.Monadic.return (Fuzz.State.Monad.Monadic.return x)
end

let output () : Common.Output.t Runner_state.Monad.t =
  Runner_state.Monad.Monadic.return (Fuzz.State.Monad.output ())

let generate_payload (type rs)
    (module Act : Fuzz.Action_types.S with type Payload.t = rs)
    (subject : Fuzz.Subject.Test.t) : rs Runner_state.Monad.t =
  Runner_state.(
    Monad.(
      Let_syntax.(
        let%bind o = output () in
        let%bind ctx = make_gen_context Act.name subject in
        Common.Output.pv o "fuzz: generating random state for %a...@."
          Common.Id.pp Act.name ;
        let%map g = return_err (Fuzz.Payload_gen.run Act.Payload.gen ~ctx) in
        Common.Output.pv o "fuzz: done generating random state.@." ;
        g)))

let available (module A : Fuzz.Action_types.S)
    ~(subject : Fuzz.Subject.Test.t) : bool Runner_state.Monad.t =
  Runner_state.(
    Monad.(
      make_actx subject
      >>= fun ctx -> return_err (Fuzz.Availability.M.run A.available ~ctx)))

let pick (s : Runner_state.t) : (Runner_state.t * Fuzz.Action.t) Or_error.t =
  Or_error.Let_syntax.(
    let%map (action, pool') = Action_pool.pick s.pool ~random:s.random in
    let s' = s.@(Runner_state.pool) <- pool' in (s', action))

let pick_step (mu : Fuzz.Action.t option -> Fuzz.Action.t option Runner_state.Monad.t)
  ~(subject : Fuzz.Subject.Test.t)
  : Fuzz.Action.t option Runner_state.Monad.t =
  Runner_state.Monad.(
    Let_syntax.(
      let%bind action = Monadic.make (Fn.compose Fuzz.State.Monad.Monadic.return pick) in
      (* Keep going until we find an available action, or hit an error eg
         running out of actions. *)
      if%bind available action ~subject
      then return (Some action)
      else mu None
   )
  )

let pick_loop (subject : Fuzz.Subject.Test.t) : Fuzz.Action.t option Runner_state.Monad.t =
  Runner_state.Monad.(fix None ~f:(fun mu xo ->
    match xo with
    | Some x -> return (Some x)
    | None -> pick_step mu ~subject
  ))

let pick_action (subject : Fuzz.Subject.Test.t) :
  (module Fuzz.Action_types.S) Runner_state.Monad.t =
  Runner_state.Monad.(Let_syntax.(
    let%bind ao = pick_loop subject in
    let%bind () = Runner_state.(modify_acc pool Action_pool.reset) in
    (* We should never end up with an empty action; either the picker should
       fail to pick, or it should pick a concrete action.  Nevertheless, the
       contrivances of the monad fixpoint mean we need to account for this. *)
    match ao with
    | Some a -> return a
    | None -> Runner_state.return_err (Or_error.error_string "no action picked")
  )
)

let log_action (type p)
    (action : (module Fuzz.Action_types.S with type Payload.t = p))
    (payload : p) : unit Runner_state.Monad.t =
  Runner_state.Monad.modify (fun x ->
      {x with trace= Fuzz.Trace.add x.trace ~action ~payload})

let run_action (module Action : Fuzz.Action_types.S)
    (subject : Fuzz.Subject.Test.t) :
    Fuzz.Subject.Test.t Runner_state.Monad.t =
  Runner_state.Monad.Let_syntax.(
    (* We can't, AFAIK, move the payload out of this function, as then the
       subject step runner would become dependent on the exact type of the
       payload, and this is encapsulated in [Action]. *)
    let%bind payload = generate_payload (module Action) subject in
    let%bind () = log_action (module Action) payload in
    Runner_state.Monad.Monadic.return (Action.run subject ~payload))

let mutate_subject_step (subject : Fuzz.Subject.Test.t) :
    Fuzz.Subject.Test.t Runner_state.Monad.t =
  Runner_state.Monad.Let_syntax.(
    let%bind o = output () in
    Common.Output.pv o "fuzz: picking action...@." ;
    let%bind action = pick_action subject in
    Common.Output.pv o "fuzz: done; now running action...@." ;
    run_action action subject
    >>= Runner_state.Monad.tee ~f:(fun _ ->
            Common.Output.pv o "fuzz: action done.@."))

let get_cap () : int Runner_state.Monad.t =
  Runner_state.Monad.(
    Let_syntax.(
      let%bind param_map = peek (fun x -> x.params) in
      Monadic.return
        Fuzz.State.Monad.(
          Monadic.return (Fuzz.Param_map.get_action_cap param_map))))

let mutate_subject (subject : Fuzz.Subject.Test.t) :
    Fuzz.Subject.Test.t Runner_state.Monad.t =
  Runner_state.Monad.Let_syntax.(
    let%bind cap = get_cap () in
    let%map _, subject' =
      Runner_state.Monad.fix (cap, subject)
        ~f:(fun mu (remaining, subject') ->
          if Int.(remaining = 0) then return (remaining, subject')
          else
            let%bind subject'' = mutate_subject_step subject' in
            mu (remaining - 1, subject''))
    in
    subject')

let make_runner_state (seed : int option) (config : Config.t) :
    Runner_state.t Or_error.t =
  let random = make_rng seed in
  let trace = Fuzz.Trace.empty in
  Or_error.Let_syntax.(
    let params = Config.make_param_map config in
    let%bind queue_flag =
      Fuzz.Param_map.get_flag params
        ~id:Fuzz.Config_tables.take_recommendation_flag
    in
    let%map pool = Config.make_pool config ~queue_flag in
    {Runner_state.random; trace; pool; params})

let make_output (rstate : Runner_state.t) (subject : Fuzz.Subject.Test.t) :
    Fuzz.Trace.t Fuzz.Output.t =
  Fuzz.Output.make ~subject ~metadata:rstate.trace

let run ?(seed : int option) (subject : Fuzz.Subject.Test.t)
    ~(config : Config.t) : Fuzz.Trace.t Fuzz.Output.t Fuzz.State.Monad.t =
  Fuzz.State.Monad.(
    Let_syntax.(
      let%bind runner_state =
        Monadic.return (make_runner_state seed config)
      in
      let%map state, subject' =
        Runner_state.Monad.run' (mutate_subject subject) runner_state
      in
      make_output state subject'))
