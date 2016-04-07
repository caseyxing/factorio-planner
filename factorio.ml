(******************************************************************************)
(* Copyright (c) 2016 DooMeeR                                                 *)
(*                                                                            *)
(* Permission is hereby granted, free of charge, to any person obtaining      *)
(* a copy of this software and associated documentation files (the            *)
(* "Software"), to deal in the Software without restriction, including        *)
(* without limitation the rights to use, copy, modify, merge, publish,        *)
(* distribute, sublicense, and/or sell copies of the Software, and to         *)
(* permit persons to whom the Software is furnished to do so, subject to      *)
(* the following conditions:                                                  *)
(*                                                                            *)
(* The above copyright notice and this permission notice shall be             *)
(* included in all copies or substantial portions of the Software.            *)
(*                                                                            *)
(* THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,            *)
(* EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF         *)
(* MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND                      *)
(* NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE     *)
(* LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION     *)
(* OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION      *)
(* WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.            *)
(******************************************************************************)

type maker =
  {
    name: string;
    crafting_speed: float;
  }

let maker name crafting_speed = { name; crafting_speed }

type style =
  | Global
  | Local

type ressource =
  {
    name: string;
    makers: maker list;
    time: float;
    ingredients: (float * ressource) list;
    count: float; (* Usually 1, but sometimes 2 like for Copper Cables. *)
    mutable style: style;
  }

let res ?(count = 1.) ?(style = Local) name makers time ingredients =
  { name; makers; time; ingredients; count; style }

(******************************************************************************)
(*                                  Summarize                                 *)
(******************************************************************************)

type summary =
  {
    throughput: float; (* goal count per second *)
    goal: string; (* goal ressource name *)
    makers: (float * string) list; (* count, name *)
    subgoals: summary list;
  }

(* Summarize in a tree style. Don't detail global ressources. *)
let rec summarize_local throughput (ressource: ressource): summary =
  match ressource.style with
    | Local ->
        let makers =
          let make_maker (maker: maker) =
            let maker_count =
              throughput /. ressource.count *.
              ressource.time /. maker.crafting_speed
            in
            maker_count, maker.name
          in
          List.map make_maker ressource.makers
        in
        let subgoals =
          let make_subgoal (count, ingredient) =
            summarize_local
              (throughput /. ressource.count *. count)
              ingredient
          in
          List.map make_subgoal ressource.ingredients
        in
        {
          throughput;
          goal = ressource.name;
          makers;
          subgoals;
        }
    | Global ->
        {
          throughput;
          goal = ressource.name;
          makers = [];
          subgoals = [];
        }

(* Detail global ressources only. *)
let summarize_global throughput (ressource: ressource) =
  let table = Hashtbl.create 16 in
  let add throughput ressource =
    let previous_throughput =
      match Hashtbl.find table ressource.name with
        | exception Not_found ->
            0.
        | tp, _ ->
            tp
    in
    Hashtbl.replace table ressource.name
      (previous_throughput +. throughput, ressource)
  in
  let rec search throughput ressource =
    begin
      match ressource.style with
        | Local -> ()
        | Global -> add throughput ressource
    end;
    List.iter
      (fun (count, ingredient) ->
         search (throughput /. ressource.count *. count) ingredient)
      ressource.ingredients
  in
  search throughput ressource;
  let result = ref [] in
  Hashtbl.iter
    (fun _ (throughput, ressource) ->
       result :=
         summarize_local throughput { ressource with style = Local }
         :: !result)
    table;
  List.rev !result