load("@rules_python//python:defs.bzl", "py_binary", "py_test")
load("@io_bazel_rules_docker//lang:image.bzl", "app_layer")
load("@test_poetry_no_groups//:dependencies.bzl", "dependency")

py_test(
    name = "test_valid_import",
    size = "small",
    srcs = ["test_valid_import.py"],
    python_version = "PY3",
    deps = [
        dependency("pandas"),
        dependency("numpy"),
    ],
)
