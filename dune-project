(lang dune 3.5)

(name jitterbug)

(generate_opam_files true)

(source
 (github sadiqj/jitterbug))

(authors "Sadiq Jaffer")

(maintainers "Sadiq Jaffer")

(license ISC)

(package
 (name jitterbug)
 (synopsis "Measures GC/runtime jitter")
 (description "Measures GC/runtime jitter")
 (depends (ocaml (>= 5.0)) dune hdr_histogram)
)

; See the complete stanza docs at https://dune.readthedocs.io/en/stable/dune-files.html#dune-project
