workspace(
    name = "com_sonia_rules_poetry",
)

load("@bazel_tools//tools/build_defs/repo:http.bzl", "http_archive")

http_archive(
    name = "rules_python",
    strip_prefix = "rules_python-54d1cb35cd54318d59bf38e52df3e628c07d4bbc",
    urls = ["https://github.com/bazelbuild/rules_python/archive/54d1cb35cd54318d59bf38e52df3e628c07d4bbc.tar.gz"],
    sha256 = "43c007823228f88d6afe1580d00f349564c97e103309a234fa20a5a10a9ff85b",
)

# This call should always be present.
load("@rules_python//python:repositories.bzl", "py_repositories")
py_repositories()

# Split remarshal out, most consumers will not need it
local_repository(
    name = "remarshal",
    path = "remarshal",
)

# Poetry rules
load("//rules_poetry:poetry.bzl", "poetry")

poetry(
    name = "test_poetry",
    lockfile = "//test:poetry.lock",
    pyproject = "//test:pyproject.toml",
)
