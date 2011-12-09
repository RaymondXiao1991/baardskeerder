(*
 * This file is part of Baardskeerder.
 *
 * Copyright (C) 2011 Incubaid BVBA
 *
 * Baardskeerder is free software: you can redistribute it and/or modify
 * it under the terms of the GNU Lesser General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * Baardskeerder is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU Lesser General Public License for more details.
 *
 * You should have received a copy of the GNU Lesser General Public License
 * along with Baardskeerder.  If not, see <http://www.gnu.org/licenses/>.
 *)

open Base
open Tree
open Log
open Entry
open Slab
open Commit

module DBX(L:LOG) = struct

  type tx = { log: L.t; slab: Slab.t; 
              mutable actions: action list}

  module DBL = DB(L)

  let get tx k = DBL.get tx.log tx.slab k

  let set tx k v = 
    let vpos = Inner (Slab.length tx.slab) in
    let _ = DBL._set tx.log tx.slab k v in 
    let a = Set (k, vpos) in
    let () = tx.actions <- a :: tx.actions in
    ()

  let delete tx k = 
    let _ = DBL._delete tx.log tx.slab k in 
    let a = Delete k in
    let () = tx.actions <- a :: tx.actions in
    ()


  let with_tx ?(inc=Time.next_major) log f = 
    let now = L.now log in
    let fut = inc now in
    let slab = Slab.make fut in
    let tx = {log;slab;actions = []} in
    let () = f tx in
    let root = Slab.length tx.slab -1 in
    let last = L.last log in
    let commit = make_commit (Inner root) last fut (List.rev tx.actions) in
    let c = Commit commit in
    let _ = Slab.add tx.slab c in
    (* let slab' = slab in *)
    let slab' = Slab.compact tx.slab in 
    L.write log slab'

end
