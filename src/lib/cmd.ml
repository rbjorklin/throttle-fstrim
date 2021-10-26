open Cmdliner

type config = {
  length : int;
  max_queue : float;
}

let length_term =
  let default = 64000000 in
  let info =
    Arg.info
      [ "l"; "length" ] (* '-U' and '--username' will be synonyms *)
      ~docv:"LENGTH" ~doc:"Number of bytes to trim in each execution."
  in
  Arg.value (Arg.opt Arg.int default info)

let max_queue_term =
  let default = 1. in
  let info =
    Arg.info
      [ "q"; "max-queue" ] (* '-U' and '--username' will be synonyms *)
      ~docv:"QUEUE"
      ~doc:"Max queue size allowed before starting to sleep between executions."
  in
  Arg.value (Arg.opt Arg.float default info)

let conf_term =
  let combine length max_queue = { length; max_queue } in
  Term.(const combine $ length_term $ max_queue_term)

let parse_command_line () =
  let info =
    Term.info "throttle-fstrim"
    (* program name as it will appear in --help *)
  in
  match Term.eval (conf_term, info) with
  | `Error _ -> exit 1
  | `Version | `Help -> exit 0
  | `Ok conf -> conf