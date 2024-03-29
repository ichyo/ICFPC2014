
open Str
open Stack

type data =
    Int of int
  | Cons of data * data
  | Closure of int * frame
  | Join of int
  | Ret of int
  | Stop
  | Frame of frame
and frame = {
  parent : frame option;
  vars : data array;
  mutable dummy : bool;
}

exception Tag_mismatch of int
exception Control_mismatch of int
exception Frame_mismatch of int
exception Machine_stop of data

let rec pp_data ppf =
  let open Format in
  function
  | Int x -> fprintf ppf "INT %d" x
  | Cons (car, cdr) -> fprintf ppf "(%a, %a)" pp_data car pp_data cdr
  | Closure (x, y) -> fprintf ppf "CLOSURE (%d, %a)" x pp_frame y
  | Join x -> fprintf ppf "JOIN %d" x
  | Ret x -> fprintf ppf "RET %d" x
  | Stop -> fprintf ppf "STOP"
  | Frame f -> fprintf ppf "FRAME %a" pp_frame f
and pp_frame ppf f =
  let open Format in
  match f.parent with
    Some p -> fprintf ppf "{%a; [%a]; %b}" pp_frame p pp_vars f.vars f.dummy
  | None   -> fprintf ppf "{*; [%a]; %b}" pp_vars f.vars f.dummy
and pp_vars ppf vs =
  Array.iter (fun d -> Format.fprintf ppf "%a," pp_data d) vs

let string_of_data data =
  pp_data Format.str_formatter data;
  Format.flush_str_formatter ()

let string_of_frame frame =
  pp_frame Format.str_formatter frame;
  Format.flush_str_formatter ()
                             
let print_data data = pp_data Format.std_formatter data


let data_stack : data Stack.t = create ()
and ctrl_stack : data Stack.t = create ()
and envf = ref {parent = None; vars = [||]; dummy = true}

let ireg inst n =
  let rec loc inst = function
      0 -> inst
    | n -> inst ^ " +\\([0-9]+\\)" ^ (loc "" (n - 1))
  in regexp_case_fold (" *" ^ (loc inst n))

let rec search f n i pc =
  let rec loc f = function
      0 -> if f.dummy then raise (Frame_mismatch !pc)
           else f.vars.(i)
    | n -> match f.parent with
             Some p -> loc p (n - 1)
           | None -> failwith "search failed"
  in loc f n

let modify_var f n i pc =
  let x = pop data_stack in
  let rec loc f = function
      0 -> if f.dummy then raise (Frame_mismatch !pc)
           else f.vars.(i) <- x
    | n -> match f.parent with
             Some p -> loc p (n - 1)
           | None -> failwith "search failed"
  in loc f n

let binop f pc =
  let x = pop data_stack and
      y = pop data_stack in
  begin
    match x, y with
      Int n, Int m -> push (Int (f n m)) data_stack
    | _, _ -> raise (Tag_mismatch !pc)
  end;
  incr pc

let rec replace_vars arr = function
    0 -> arr
  | i -> let y = pop data_stack in
         arr.(i - 1) <- y;
         replace_vars arr (i - 1)

let new_vars n =
  replace_vars (Array.make n (Int 0)) n

let of_list _s =
  let rec loc s acc =
    try let h = pop s in loc s (h :: acc)
    with _ -> acc
  in loc (copy _s) []

let dump pc =
  let open Printf in
  print_string "---\n";
  printf "pc: %d\n" !pc;
  printf "frame: %s\n" (string_of_frame !envf);
  print_string "data_stack:\n";
  List.iter (fun d -> printf "%s\n" (string_of_data d)) (of_list data_stack);
  print_string "ctrl_stack:\n";
  List.iter (fun d -> printf "%s\n" (string_of_data d)) (of_list ctrl_stack)

let rec step program pc =
  let line = program.(!pc) in
  (* dump pc; *)
  (* Printf.printf "line: \"%s\"\n" line; *)
  (* ignore (read_line ()); *)
  begin
    if string_match (ireg "ldc" 1) line 0
    then (
      push (Int (int_of_string (matched_group 1 line))) data_stack;
      incr pc
    )
    else if string_match (ireg "ld" 2) line 0
    then let n = int_of_string (matched_group 1 line) and
             i = int_of_string (matched_group 2 line) in
         push (search !envf n i pc) data_stack;
         incr pc
    else if string_match (ireg "add" 0) line 0
    then binop (fun y x -> x + y) pc
    else if string_match (ireg "sub" 0) line 0
    then binop (fun y x -> x - y) pc
    else if string_match (ireg "mul" 0) line 0
    then binop (fun y x -> x * y) pc
    else if string_match (ireg "div" 0) line 0
    then binop (fun y x -> x / y) pc
    else if string_match (ireg "ceq" 0) line 0
    then binop (fun y x -> if x == y then 1 else 0) pc
    else if string_match (ireg "cgt" 0) line 0
    then binop (fun y x -> if x > y then 1 else 0) pc
    else if string_match (ireg "cgte" 0) line 0
    then binop (fun y x -> if x >= y then 1 else 0) pc
    else if string_match (ireg "atom" 0) line 0
    then let x = pop data_stack in
         push (Int (match x with Int _ -> 1 | _ -> 0)) data_stack;
         incr pc
    else if string_match (ireg "cons" 0) line 0
    then let y = pop data_stack and
             x = pop data_stack in
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
           Int x -> push (Join (!pc + 1)) ctrl_stack;
                    if x == 0
                    then pc := int_of_string (matched_group 2 line)
                    else pc := int_of_string (matched_group 1 line)
         | _ -> raise (Tag_mismatch !pc)
         )
    else if string_match (ireg "join" 0) line 0
    then let x = pop ctrl_stack in
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
             let new_f = {parent = Some e; vars = new_vars n; dummy = false} in
             push (Frame !envf) ctrl_stack;
             push (Ret (!pc + 1)) ctrl_stack;
             envf := new_f;
             pc := f
           )
         | _ -> raise (Tag_mismatch !pc)
    else if string_match (ireg "rtn" 0) line 0
    then let x = pop ctrl_stack in
         (* print_string ((string_of_data x) ^ "\n"); *)
         match x with
           Stop -> raise (Machine_stop (pop data_stack))
         | Ret p -> let y = pop ctrl_stack in (
                      match y with
                        Frame f -> envf := f;
                                   pc := p
                      | _ -> raise (Control_mismatch !pc)
                    )
         | _ -> raise (Control_mismatch !pc)
    else if string_match (ireg "dum" 1) line 0
    then let n = int_of_string (matched_group 1 line) in
         let fp = {parent = Some !envf;
                   vars = Array.make n (Int 0);
                   dummy = true} in
         envf := fp;
         incr pc
    else if string_match (ireg "rap" 1) line 0
    then let x = pop data_stack and
             n = int_of_string (matched_group 1 line) in
         match x with
           Closure (f, fp) ->
           if !envf.dummy = false
              || Array.length !envf.vars != n
              || !envf != fp
           then raise (Frame_mismatch !pc)
           else (
             match !envf.parent with
               None -> failwith ("RAP: parent is not found; " ^ (string_of_int !pc))
             | Some p -> (
               ignore (replace_vars fp.vars n);
               push (Frame p) ctrl_stack;
               push (Ret (!pc + 1)) ctrl_stack;
               fp.dummy <- false;
               envf := fp;
               pc := f
             )
           )
         | _ -> raise (Tag_mismatch !pc)
    else if string_match (ireg "stop" 0) line 0
    then raise (Machine_stop (pop data_stack))
    else if string_match (ireg "tsel" 2) line 0
    then let x = pop data_stack in
         match x with
           Int x -> let t = int_of_string (matched_group 1 line) and
                        f = int_of_string (matched_group 2 line) in
                    pc := (if x == 0 then f else t)
         | _ -> raise (Tag_mismatch !pc)
    else if string_match (ireg "tap" 1) line 0
    then let x = pop data_stack in
         match x with
           Closure (f, e) ->
           (
             let n = int_of_string (matched_group 1 line) in
             let new_f = {parent = Some e; vars = new_vars n; dummy = false} in
             envf := new_f;
             pc := f
           )
         | _ -> raise (Tag_mismatch !pc)
    else if string_match (ireg "trap" 1) line 0
    then let x = pop data_stack and
             n = int_of_string (matched_group 1 line) in
         match x with
           Closure (f, fp) ->
           if !envf.dummy = false
              || Array.length !envf.vars != n
              || !envf != fp
           then raise (Frame_mismatch !pc)
           else (
             match !envf.parent with
               None -> failwith ("RAP: parent is not found; " ^ (string_of_int !pc))
             | Some p -> (
               ignore (replace_vars fp.vars n);
               fp.dummy <- false;
               envf := fp;
               pc := f
             )
           )
         | _ -> raise (Tag_mismatch !pc)
    else if string_match (ireg "st" 2) line 0
    then let n = int_of_string (matched_group 1 line) and
             i = int_of_string (matched_group 2 line) in
         modify_var !envf n i pc;
         incr pc
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

let next_int str idx =
  if string_match (regexp "[0-9]+") str !idx
  then
    let ret = int_of_string (matched_string str) in
    idx := match_end ();
    ret
  else
    failwith ("program error: " ^ (string_of_int !idx))

let decode str =
  let idx = ref 0 in
  let rec parse str idx =
    if String.get str !idx = '('
    then (
      idx := !idx + 1;            (* skip ) *)
      let car = parse str idx in
      idx := !idx + 1;            (* skip comma *)
      let cdr = parse str idx in
      idx := !idx + 1;            (* skip ) *)
      Cons (car, cdr)
    )
    else
      let a = next_int str idx in Int a
  in parse (global_replace (regexp "[^0-9(),]") "" str) idx

let rec encode =
  let open Printf in
  function               (* toriaezu cons wo soreppoku dump *)
    Int x -> sprintf "%d" x
  | Cons (car, cdr) -> sprintf "(%s,%s)" (encode car) (encode cdr)
  | _ -> failwith "encode: unexpected"

let run program =
  let pc = ref 0 in
  try step program pc
  with Machine_stop d -> print_string (encode d)

let () =
  let program = read_program (open_in Sys.argv.(1)) (Array.make 0 "") in
  Array.iter (fun s -> Printf.printf "%s\n" s) program;
  push Stop ctrl_stack;
  push (decode (read_line ())) data_stack;
  run program
