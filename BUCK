# buildifier: disable=no-effect
ocaml_binary(
    name = "throttle-fstrim",
    srcs = ["src/bin/throttle_fstrim.ml"],
    deps = [":cmd",
    "//third-party/ocaml:unix",
    "//third-party/ocaml:fmt",
    "//third-party/ocaml:logs",
    "//third-party/ocaml:logs.fmt"],
) if not host_info().os.is_windows else None

# buildifier: disable=no-effect
ocaml_library(
    name = "cmd",
    srcs = ["src/lib/cmd.ml"],
    deps = ["//third-party/ocaml:cmdliner"],
    visibility = ["PUBLIC"],
) if not host_info().os.is_windows else None
