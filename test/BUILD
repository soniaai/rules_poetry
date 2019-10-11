load("@rules_python//python:defs.bzl", "py_binary", "py_test")
load("@io_bazel_rules_docker//lang:image.bzl", "app_layer")
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

py_binary(
    name = "timezone",
    srcs = ["timezone.py"],
    python_version = "PY3",
    deps = [
        dependency("pytz"),
    ],
)

# can't use the py3_image rule until I figure out how to register a CC toolchain that works in Docker
app_layer(
    name = "timezone.image",
    base = "@python_debian//image",
    binary = ":timezone",
    tags = ["manual"],
)
