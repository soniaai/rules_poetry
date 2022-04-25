workspace(
    name = "com_sonia_rules_poetry",
)

load("@bazel_tools//tools/build_defs/repo:http.bzl", "http_archive")

http_archive(
    name = "rules_python",
    sha256 = "cdf6b84084aad8f10bf20b46b77cb48d83c319ebe6458a18e9d2cebf57807cdd",
    strip_prefix = "rules_python-0.8.1",
    url = "https://github.com/bazelbuild/rules_python/archive/refs/tags/0.8.1.tar.gz",
)

# This call should always be present.
load("@rules_python//python:repositories.bzl", "py_repositories")

py_repositories()

# install pip and setuptools locally
load("@com_sonia_rules_poetry//rules_poetry:defs.bzl", "poetry_deps")

poetry_deps()

# Docker rules for testing

http_archive(
    name = "io_bazel_rules_docker",
    sha256 = "413bb1ec0895a8d3249a01edf24b82fd06af3c8633c9fb833a0cb1d4b234d46d",
    strip_prefix = "rules_docker-0.12.0",
    urls = ["https://github.com/bazelbuild/rules_docker/releases/download/v0.12.0/rules_docker-v0.12.0.tar.gz"],
)

load(
    "@io_bazel_rules_docker//repositories:repositories.bzl",
    _container_repositories = "repositories",
)

_container_repositories()

load("@io_bazel_rules_docker//repositories:deps.bzl", _container_deps = "deps")

_container_deps()

# Split remarshal out, most consumers will not need it
local_repository(
    name = "remarshal",
    path = "remarshal",
)

# Poetry rules
load("//rules_poetry:poetry.bzl", "poetry")

poetry(
    name = "test_poetry",
    excludes = [
        "enum34",
        "setuptools",
    ],
    lockfile = "//test:poetry.lock",
    pyproject = "//test:pyproject.toml",
)

# Base image for Docker tests
load(
    "@io_bazel_rules_docker//container:container.bzl",
    "container_pull",
)

container_pull(
    name = "python_debian",
    digest = "sha256:fc754aafacf5ad737f1e313cbd3f7cfedf08cbc713927a9e27683b7210a0aabd",
    registry = "index.docker.io",
    repository = "library/python",
    tag = "3.7.4-slim-buster",
)
