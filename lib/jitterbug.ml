let () =
  Domain.spawn(fun () ->
    let jitter_out = open_out "jitter.txt" in
    let i = ref 0 in
    let counts = ref 0 in
    let h = Hdr_histogram.init ~lowest_discernible_value:1 ~highest_trackable_value:100_000_000
    ~significant_figures:3 in
    while true do
      incr i;
      let start_time = Unix.gettimeofday () in
      for j = 0 to 2 do
        ignore(Sys.opaque_identity(j))
      done;
      let duration = Unix.gettimeofday () -. start_time in
      let duration_micros = duration *. 1000000.0 |> Float.to_int in
      if duration_micros > 1 then begin
        incr counts;
        Hdr_histogram.record_value h duration_micros |> ignore;
      end;
      if !i mod 1000 == 0 then begin
        Printf.fprintf jitter_out "%d %d %f %d %d %d %d %d\n%!"
        !counts
        (Hdr_histogram.min h)
        (Hdr_histogram.mean h)
        (Hdr_histogram.value_at_percentile h 50.)
        (Hdr_histogram.value_at_percentile h 99.)
        (Hdr_histogram.value_at_percentile h 99.9)
        (Hdr_histogram.value_at_percentile h 99.99)
        (Hdr_histogram.max h)
      end;
      Unix.sleepf 0.001;
    done
  ) |> ignore