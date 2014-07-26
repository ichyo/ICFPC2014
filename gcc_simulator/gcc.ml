
open Str
open Stack
open Printf

(* let data = create ()
and ctrl = create ()
and envf = create ()
and heap = create () *)

let ireg inst n =
  let rec loc inst = function
      0 -> inst
    | n -> inst ^ " \\([0-9]+\\)" ^ (loc "" (n - 1))
  in regexp (loc inst n)

let step program pc =
  let line = program.(pc) in
  if string_match (regexp 
  

let rec read_program fp arr =
  try
    let line = input_line fp in
    read_program fp (Array.append arr (Array.make 1 line))
  with End_of_file ->
    close_in fp; arr

let () =
  let program = read_program (open_in Sys.argv.(1)) (Array.make 0 "") in
  Array.iter (fun s -> printf "%s\n" s) program
