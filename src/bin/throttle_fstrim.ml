open Cmdliner

(*
let timestamp_tag : Logs.Tag.def =
  Logs.Tag.def "timestamp" ~doc:"Timestamp in localtime." Logs.Tag.pp_def
  *)

(* let timestamp c = Logs.Tag.(empty |> add timestamp_tag (Mtime_clock.count c)) *)

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

type mount = {
  device : string;
  path : string;
  filesystem : string;
}

type diskstat = {
  device : string;
  io_time : int;
}

module StringMap = Map.Make (String)

let getline ic =
  input_line ic |> String.split_on_char ' ' |> List.filter (fun s -> s <> "")

let read_mounts () =
  let mounts_ic = open_in "/proc/mounts" in
  let rec inner mounts =
    match getline mounts_ic with
    | exception End_of_file ->
        close_in mounts_ic;
        List.rev mounts
        (* no need to construct option types just to consume them *)
    | device :: path :: filesystem :: _ -> (
        (* lists are better destructured than accessed with nth *)
        match filesystem with
        | "xfs" | "ext4" | "btrfs" ->
            let resolved_device =
              if (Unix.lstat device).st_kind = Unix.S_LNK then
                Filename.basename (Unix.readlink device)
              else Filename.basename device
            in
            inner ({ device = resolved_device; path; filesystem } :: mounts)
            (* name punning *)
            (* and lists are better consed than appended to *)
        | _ -> inner mounts)
    | _ ->
        (* a list with less than 3 elems *)
        Printf.eprintf "ERROR: Ill formed line.";
        inner mounts
  in
  inner []

let read_diskstats () =
  let diskstats_ic = open_in "/proc/diskstats" in
  let rec inner diskstats =
    match getline diskstats_ic with
    | exception End_of_file ->
        close_in diskstats_ic;
        diskstats
    | _ :: _ :: device :: tl ->
        (* See Field 11: https://www.kernel.org/doc/html/latest/admin-guide/iostats.html?highlight=11 *)
        inner
          (StringMap.add device
             { device; io_time = int_of_string (List.nth tl 10) }
             diskstats)
    | _ ->
        Printf.eprintf "ERROR: Ill formed line.";
        inner diskstats
  in
  inner StringMap.empty

let fstrim ?(length = 64000000) ?(max_queue = 1.) (mounts : mount list) =
  List.iter
    (fun (mount : mount) ->
      Printf.printf "%s, %s, %s\n" mount.device mount.path mount.filesystem;
      flush_all ();
      let rec loop mount offset =
        let now = Unix.localtime (Unix.time ()) in
        let start =
          int_of_float (Float.floor (Unix.gettimeofday () *. 1000.))
        in
        let stats_before = read_diskstats () in
        let fstrim_ic =
          Unix.open_process_args_in "/usr/sbin/fstrim"
            [|
              "fstrim";
              "--offset";
              string_of_int offset;
              "--length";
              string_of_int length;
              mount.path;
            |]
        in
        match Unix.close_process_in fstrim_ic with
        | WEXITED exit_code when exit_code = 0 ->
            let stats_after = read_diskstats () in
            let stop =
              int_of_float (Float.ceil (Unix.gettimeofday () *. 1000.))
            in
            let weighted_time_spent_trimming =
              StringMap.fold
                (fun key after_elem acc ->
                  let before_elem = StringMap.find key stats_before in
                  (after_elem.io_time - before_elem.io_time) :: acc)
                stats_after []
              |> List.fold_left
                   (fun x max -> if x > max then x else max)
                   Int.min_int
            in
            let time_delta = stop - start in
            let queued =
              float_of_int weighted_time_spent_trimming
              /. float_of_int time_delta
            in
            Printf.eprintf
              "%d:%d:%d queue_size: %f, offset: %d, time_delta: %d, \
               weighted_time_spent_trimming: %d\n"
              now.tm_hour now.tm_min now.tm_sec queued offset time_delta
              weighted_time_spent_trimming;
            flush_all ();
            if queued > max_queue then
              Printf.printf "sleeping %dms\n" time_delta;
            Unix.sleepf (float_of_int time_delta /. 1000.);
            loop mount (offset + length)
        | WEXITED exit_code when exit_code = 1 ->
            Printf.printf "Reached end of filesystem boundry, moving on.\n"
        | WEXITED exit_code ->
            Printf.eprintf "Failed with exit code: %d\n" exit_code
        | WSIGNALED signal -> Printf.eprintf "Killed with signal: %d\n" signal
        | WSTOPPED signal -> Printf.eprintf "Stopped with signal: %d\n" signal
        (*| _ -> Printf.eprintf "something went wrong\n"*)
      in
      loop mount 0)
    mounts

let main length max_queue =
  Logs.set_reporter (Logs_fmt.reporter ());
  Logs.set_level (Some Logs.Info);
  Logs.info (fun m -> m "test");
  read_mounts () |> fstrim ~length ~max_queue

let () =
  let conf = parse_command_line () in
  main conf.length conf.max_queue
