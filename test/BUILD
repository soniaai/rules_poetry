load("@rules_python//python:defs.bzl", "py_test")
load("@test_poetry//:dependencies.bzl", "dependency")

py_test(
    name = "test_valid_import",
    size = "small",
    srcs = ["test_valid_import.py"],
    python_version = "PY3",
    deps = [
        dependency("pandas"),
    ],
)

py_test(
    name = "test_invalid_import",
    size = "small",
    srcs = ["test_invalid_import.py"],
    python_version = "PY3",
    deps = [
        dependency("numpy"),
    ],
)

