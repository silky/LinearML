open Utils
open Stast

type ty = 
  | Prim
  | Obs of Pos.t
  | Fresh of Pos.t
  | Used of Pos.t

let debug = function
  | Prim -> o "Prim"
  | Obs _ -> o "Obs"
  | Fresh _ -> o "Fresh"
  | Used _ -> o "Used"

let get x t = try IMap.find x t with Not_found -> Prim

let is_obs = function
  | _, Tapply ((_, x), _) when x = Naming.tobs -> true
  | _ -> false

let union t t' = IMap.fold IMap.add t' t

let rec unify_map m1 m2 = 
  unify_map_ (unify_map_ m1 m2) m1

and unify_map_ (p1, m1) (p2, m2) =
  p1, IMap.fold (fun x t2 acc -> try
    let t1 = IMap.find x m1 in
    IMap.add x (unify (p1, t1) (p2, t2)) acc
    with Not_found -> 
      match t2 with
      | Prim
      | Obs _
      | Used _ -> acc
      | Fresh p -> Error.forgot_free p) m2 m1

and unify (p1, ty1) (p2, ty2) = 
  match ty1, ty2 with
  | Prim, Prim -> Prim
  | Obs p, Obs _ -> Obs p
  | Fresh p, Fresh _ -> Fresh p
  | Used p, Used _ -> Used p
  | Used _, Fresh p -> Error.forgot_free_branch p p2
  | Fresh p, Used _ -> Error.forgot_free_branch p p1
  | Used p, Obs p2 -> Error.pos p ; Error.pos p2 ; assert false
  | ty1, ty2 -> debug ty1 ; debug ty2 ; failwith "TODO ERROR unify"

let check_observable ty = 
  if is_obs ty
  then ()
  else Error.underscore_obs (fst ty)

let check_alive t = 
  IMap.iter (
  fun x ty ->
    match ty with
    | Fresh p -> Error.unused_variable p
    | _ -> ()
 ) t

let rec program mdl = 
  List.iter (module_ IMap.empty) mdl

and module_ t md = 
  List.iter (def t) md.md_defs

and def t (_, p, e) = 
  let t = pat t p in
  let t = tuple t e in
  check_alive t

and pat t (_, ptl) = List.fold_left pat_tuple t ptl 
and pat_tuple t (_, pel) = List.fold_left pat_el t pel
and pat_el t (ty, p) = pat_ t ty p
and pat_ t ty = function
  | Pany -> (match ty with
    | _, Tprim _ -> t
    | _ -> check_observable ty ; t)

  | Pid (p, x) when is_obs ty -> IMap.add x (Obs p) t
  | Pid (p, x) -> (match snd ty with
    | Tid _ | Tapply _ | Tvar _ -> IMap.add x (Fresh p) t
    | _ -> IMap.add x Prim t)
  | Pvalue _ -> t
  | Pvariant (_, p) -> pat t p
  | Precord pfl -> List.fold_left (pat_field ty) t pfl 

and pat_field ty t (p, pf) = pat_field_ ty t p pf
and pat_field_ ty t p = function
  | PFany -> (match ty with
    | _, Tprim _ -> t
    | _ -> check_observable (p, snd ty) ; t)
  | PFid (p, x) -> IMap.add x (Fresh p) t 
  | PField (_, p) -> pat t p

and tuple t (_, tpl) = List.fold_left tuple_pos t tpl
and tuple_pos t (_, e) = expr_ t e
and expr t (_, e) = expr_ t e
and expr_ t = function
  | Eid (p, x) -> 
      (match get x t with
      | Prim
      | Obs _ -> t
      | Used p' -> Error.already_used p p'
      | _ -> IMap.add x (Used p) t)

  | Evalue _ -> t
  | Evariant (_, e) -> tuple t e
  | Ebinop (_, e1, e2) -> expr (expr t e1) e2 
  | Euop (_, e) -> expr t e
  | Erecord fdl -> List.fold_left field t fdl 
  | Ewith (e, fdl) -> List.fold_left field (expr t e) fdl 
  | Efield (_, _) -> t (* Accessing a field doesn't consume *)
  | Ematch (e, al) -> 
      let t = tuple t e in
      let tl = List.map (action t) al in
      let tl = List.map2 (fun (_, ((p, _), _)) x -> (p, x)) al tl in
      let t' = List.fold_left unify_map (List.hd tl) (List.tl tl) in
      let t' = snd t' in
      union t t'

  | Elet (p, e1, e2) -> 
      let t = tuple t e1 in
      let t = pat t p in
      tuple t e2

  | Eif (e1, e2, e3) -> 
      let t = expr t e1 in
      let t' = tuple t e2 in
      let t' = fst (fst e2), t' in
      let t'' = tuple t e3 in
      let t'' = fst (fst e3), t'' in
      let sub = unify_map t' t'' in
      let sub = snd sub in
      union t sub

  | Eobs (p, x) -> 
      (match get x t with
      | Used p' -> Error.already_used p p'
      | _ -> t)

  | Eapply (_, e) -> tuple t e 
  | Eseq (e1, e2) -> 
      let t = expr t e1 in
      tuple t e2

and field t (_, e) = tuple t e
and action t (p, e) = 
  let t = pat t p in
  tuple t e