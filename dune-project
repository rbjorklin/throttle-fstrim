(lang dune 2.7)
(name throttle-fstrim)
(generate_opam_files true)

(source (github rbjorklin/throttle-fstrim))
(license MIT)
(authors "Robin Björklin")

(package
 (name throttle-fstrim)
 (synopsis "Rudimentary support for throttling fstrim execution")
 (depends
  (dune (>= 2.9.1))
  (fmt (>= 0.8.10))
  (logs (>= 0.7.0))))

(package
 (name cmd)
 (synopsis "Handle command line args")
 (depends
  (cmdliner
    (>= 1.0.4))))
