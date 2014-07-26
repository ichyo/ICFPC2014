
open Str
open Stack

exception Tag_mismatch of int
exception Control_mismatch of int
exception Machine_stop

type data =
    Int of int
  | Cons of data * data
  | Closure of int * frame
  | Join of int
  | Ret of int
  | Stop
  | Dum of frame
  | Frame of frame
and frame = {
  parent : frame option;
  vars : data array;
}

let pp_data =
  let open Format in
  let rec pp_data ppf = function
    | Int x -> fprintf ppf "INT %d" x
    | Cons (car, cdr) -> fprintf ppf "(%a, %a)" pp_data car pp_data cdr
    | Closure (x, y) -> fprintf ppf "CLOSURE (%d, %a)" x pp_frame y
    | Join x -> fprintf ppf "JOIN %d" x
    | Ret x -> fprintf ppf "RET %d" x
    | Stop -> fprintf ppf "STOP"
    | Dum f -> fprintf ppf "DUMMY %a" pp_frame f
    | Frame f -> fprintf ppf "FRAME %a" pp_frame f
  and pp_frame ppf f =
    match f.parent with
      Some p -> fprintf ppf "{%a; [%a]}" pp_frame p pp_vars f.vars
    | None   -> fprintf ppf "{*; [%a]}" pp_vars f.vars
  and pp_vars ppf vs =
    Array.iter (fun d -> fprintf ppf "%a" pp_data d) vs
  in pp_data

let string_of_data data =
  pp_data Format.str_formatter data;
  Format.flush_str_formatter ()

let print_data data = pp_data Format.std_formatter data

let data_stack : data Stack.t = create ()
(* and ctrl_stack = create () *)
and envf = ref {parent = None; vars = [||]}
(* and heap = create () *)

let ireg inst n =
  let rec loc inst = function
      0 -> inst
    | n -> inst ^ " +\\([0-9]+\\)" ^ (loc "" (n - 1))
  in regexp_case_fold (loc inst n)

let rec search f n i =
  if n == 0 then f.vars.(i)
  else match f.parent with
         Some p -> search p (n - 1) i
       | None -> failwith "search failed"

let binop f pc =
  let x = pop data_stack and
      y = pop data_stack in
  begin
    match x, y with
      Int n, Int m -> push (Int (f n m)) data_stack
    | _, _ -> raise (Tag_mismatch !pc)
  end;
  incr pc

let new_vars n =
  let arr = Array.make n (Int 0) in
  let rec loc = function
      0 -> arr
    | i -> let y = pop data_stack in
           arr.(i - 1) <- y;
           loc (i - 1)
  in loc n

let rec step program pc =
  let line = program.(!pc) in
  begin
    if string_match (ireg "ldc" 1) line 0
    then (
      push (Int (int_of_string (matched_group 1 line))) data_stack;
      incr pc
    )
    else if string_match (ireg "ld" 2) line 0
    then let n = int_of_string (matched_group 1 line) and
             i = int_of_string (matched_group 2 line) in
         push (search !envf n i) data_stack;
         incr pc
    else if string_match (ireg "add" 0) line 0
    then binop (fun x y -> x + y) pc
    else if string_match (ireg "sub" 0) line 0
    then binop (fun x y -> x - y) pc
    else if string_match (ireg "mul" 0) line 0
    then binop (fun x y -> x * y) pc
    else if string_match (ireg "div" 0) line 0
    then binop (fun x y -> x / y) pc
    else if string_match (ireg "ceq" 0) line 0
    then binop (fun x y -> if x == y then 1 else 0) pc
    else if string_match (ireg "cgt" 0) line 0
    then binop (fun x y -> if x > y then 1 else 0) pc
    else if string_match (ireg "cgte" 0) line 0
    then binop (fun x y -> if x >= y then 1 else 0) pc
    else if string_match (ireg "atom" 0) line 0
    then let x = pop data_stack in
         push (Int (match x with Int _ -> 1 | _ -> 0)) data_stack;
         incr pc
    else if string_match (ireg "cons" 0) line 0
    then let x = pop data_stack and
             y = pop data_stack in
         push (Cons (x, y)) data_stack;
         incr pc
    else if string_match (ireg "car" 0) line 0
    then let x = pop data_stack in
         match x with
           Cons (car, _) -> push car data_stack; incr pc
         | _ -> raise (Tag_mismatch !pc)
    else if string_match (ireg "cdr" 0) line 0
    then let x = pop data_stack in
         match x with
           Cons (_, cdr) -> push cdr data_stack; incr pc
         | _ -> raise (Tag_mismatch !pc)
    else if string_match (ireg "sel" 2) line 0
    then let x = pop data_stack in (
         match x with
           Int x -> push (Join (!pc + 1)) data_stack;
                    if x == 0
                    then pc := int_of_string (matched_group 2 line)
                    else pc := int_of_string (matched_group 1 line)
         | _ -> raise (Tag_mismatch !pc)
         )
    else if string_match (ireg "join" 0) line 0
    then let x = pop data_stack in
         match x with
           Join x -> pc := x
         | _ -> raise (Control_mismatch !pc)
    else if string_match (ireg "ldf" 1) line 0
    then let f = int_of_string (matched_group 1 line) in
         push (Closure (f, !envf)) data_stack;
         incr pc
    else if string_match (ireg "ap" 1) line 0
    then let x = pop data_stack in
         match x with
           Closure (f, e) ->
           (
             let n = int_of_string (matched_group 1 line) in
             let new_f = {parent = Some e; vars = new_vars n} in
             push (Frame !envf) data_stack;
             push (Ret (!pc + 1)) data_stack;
             envf := new_f;
             pc := f
           )
         | _ -> raise (Tag_mismatch !pc)
    else if string_match (ireg "rtn" 0) line 0
    then let x = pop data_stack in
         print_string ((string_of_data x) ^ "\n");
         match x with
           Stop -> raise Machine_stop
         | Ret p -> let y = pop data_stack in (
                      match y with
                        Frame f -> envf := f;
                                   pc := p
                      | _ -> raise (Control_mismatch !pc)
                    )
         | _ -> raise (Control_mismatch !pc)
    (* else if string_match (ireg "dum" 1) line 0 *)
    (* then *)
    (* else if string_match (ireg "rap" 1) line 0 *)
    (* then *)
    (* else if string_match (ireg "stop" 0) line 0 *)
    (* then *)
    (* else if string_match (ireg "tsel" 2) line 0 *)
    (* then *)
    (* else if string_match (ireg "tap" 1) line 0 *)
    (* then *)
    (* else if string_match (ireg "trap" 1) line 0 *)
    (* then *)
    (* else if string_match (ireg "st" 2) line 0 *)
    (* then *)
    (* else if string_match (ireg "dbug" 0) line 0 *)
    (* then *)
    (* else if string_match (ireg "brk" 0) line 0 *)
    (* then *)
    else failwith ("No such operation: " ^ line)
  end;
  step program pc

let rec read_program fp arr =
  try
    let line = input_line fp in
    read_program fp (Array.append arr (Array.make 1 line))
  with End_of_file ->
    close_in fp; arr

let () =
  let program = read_program (open_in Sys.argv.(1)) (Array.make 0 "") in
  Array.iter (fun s -> Printf.printf "%s\n" s) program;
  let pc = ref 0 in step program pc
