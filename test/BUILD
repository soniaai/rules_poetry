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

py_test(
    name = "test_sys_marker",
    size = "small",
    srcs = ["test_sys_marker.py"],
    python_version = "PY3",
    deps = [
        # colorama was added with a sys_platform constraint to only install on sunos4
        dependency("colorama"),
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

"""
Some packages depend on the PATH environment variable being defined:

    File "/usr/local/Cellar/python/3.7.4_1/Frameworks/Python.framework/Versions/3.7/lib/python3.7/os.py", line 678, in __getitem__
      raise KeyError(key) from None
  KeyError: 'PATH'
"""

alias(
    name = "wrapt",
    testonly = True,
    actual = "@test_poetry//:library_wrapt",
)

# can't use the py3_image rule until I figure out how to register a CC toolchain that works in Docker
app_layer(
    name = "timezone.image",
    base = "@python_debian//image",
    binary = ":timezone",
    tags = ["manual"],
)
