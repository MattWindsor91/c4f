(* The Automagic Compiler Tormentor

   Copyright (c) 2018--2019 Matt Windsor and contributors

   ACT itself is licensed under the MIT License. See the LICENSE file in the
   project root for more information.

   ACT is based in part on code from the Herdtools7 project
   (https://github.com/herd/herdtools7) : see the LICENSE.herd file in the
   project root for more information. *)

open Base

module Make_null (Ctx : Monad.S) (Subject : Base.T) :
  Pass_types.S with type t := Subject.t and type 'a ctx := 'a Ctx.t = struct
  let run : Subject.t -> Subject.t Ctx.t = Ctx.return
end
