(** Message-passing parallel prime number generation using Sieve of Eratosthenes **)
open Effect
open Effect.Deep

(* A message is either a [Stop] signal or a [Candidate] prime number *)
type message = Stop | Candidate of int

(** Process primitives **)
type pid = int

type _ Effect.t += Spawn : (pid -> unit) -> pid Effect.t
let spawn p = perform (Spawn p)

type _ Effect.t += Yield : unit Effect.t
let yield () = perform Yield

(** Communication primitives **)
type _ Effect.t += Send : pid * message -> unit Effect.t
let send pid data =
  perform (Send (pid, data));
  yield ()

type _ Effect.t += Recv : pid -> message option Effect.t
let rec recv pid =
  match perform (Recv pid) with
  | Some m -> m
  | None -> yield (); recv pid


(** A mailbox is indexed by process ids (PIDs), each process has its own message queue **)
module Mailbox =
struct
  module Make (Ord : Map.OrderedType) =
  struct
    include Map.Make(Ord)

    let empty = empty

    let lookup key mb =
      try
        Some (find key mb)
      with
      | Not_found -> None

    let pop key mb =
      (match lookup key mb with
      | Some msg_q ->
         if Queue.is_empty msg_q then None
         else Some (Queue.pop msg_q)
       | None -> None)
      , mb

    let push key msg mb =
      match lookup key mb with
      | Some msg_q ->
         Queue.push msg msg_q;
         mb
      | None ->
         let msg_q = Queue.create () in
         Queue.push msg msg_q;
         add key msg_q mb
  end
end

(** Communication handler **)
let mailbox f =
  let module Mailbox = Mailbox.Make(struct type t = pid let compare = compare end) in
  let mailbox = ref Mailbox.empty in
  let lookup pid =
    let (msg, mb) = Mailbox.pop pid !mailbox in
    mailbox := mb; msg
  in
  try_with f () {
    effc = fun (type a) (e : a Effect.t) ->
      match e with
      | (Send (pid, msg)) -> Some (fun (k : (a, _) continuation) ->
        mailbox := Mailbox.push pid msg !mailbox;
        continue k ())
      | (Recv who) -> Some (fun k ->
          let msg = lookup who in
          continue k msg)
      | _ -> None
  }

(** Process handler
    Slightly modified version of sched.ml **)
let run main () =
  let run_q = Queue.create () in
  let enqueue k = Queue.push k run_q in
  let dequeue () =
    if Queue.is_empty run_q then ()
    else (Queue.pop run_q) ()
  in
  let pid = ref (-1) in
  let rec spawn f =
    pid := 1 + !pid;
    match_with f !pid {
      retc = (fun () -> dequeue ());
      exnc = (fun e -> raise e);
      effc = fun (type a) (e : a Effect.t) ->
        match e with
        | Yield -> Some (fun (k : (a, _) continuation) ->
          enqueue (fun () -> continue k ()); dequeue ())
        | Spawn p -> Some (fun k ->
          enqueue (fun () -> continue k !pid); spawn p)
        | _ -> None
    }
  in
  spawn main

let fromSome = function
  | Some x -> x
  | _ -> failwith "Attempt to unwrap None"

(** The prime number generator **)
let rec generator : pid -> unit =
  fun _ ->
    let n =
      if Array.length Sys.argv > 1
      then int_of_string Sys.argv.(1)
      else 101
    in
    let first = spawn sieve in  (* Spawn first sieve *)
    for i = 2 to n do
      send first (Candidate i); (* Send candidate prime to first sieve *)
    done;
    send first Stop;            (* Stop the pipeline *)
and sieve : pid -> unit =
  fun mypid ->
    match recv mypid with
    | Candidate myprime ->
       let succ = ref None in
       let rec loop () =
         let msg = recv mypid in
         match msg with
         | Candidate prime when (prime mod myprime) <> 0 ->
            let succ_pid =
              if !succ = None then
                let pid = spawn sieve in (* Create a successor process *)
                succ := Some pid;
                pid
              else fromSome !succ
            in
            send succ_pid (Candidate prime); (* Send candidate prime to successor process *)
            loop ()
         | Stop when !succ <> None ->
            send (fromSome !succ) Stop (* Forward stop command *)
         | Stop -> ()
         | _ -> loop ()
       in
       loop ()
    | _ -> ()

(* Run application *)
let _ = mailbox (run generator)