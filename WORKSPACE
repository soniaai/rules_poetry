workspace(
    name = "com_sonia_rules_poetry",
)

load("@bazel_tools//tools/build_defs/repo:http.bzl", "http_archive")

http_archive(
    name = "rules_python",
    sha256 = "8c8fe44ef0a9afc256d1e75ad5f448bb59b81aba149b8958f02f7b3a98f5d9b4",
    strip_prefix = "rules_python-0.13.0",
    url = "https://github.com/bazelbuild/rules_python/archive/refs/tags/0.13.0.tar.gz",
)

load("@rules_python//python:repositories.bzl", "python_register_toolchains")

python_register_toolchains(
    name = "rules_poetry_python3_10",
    python_version = "3.10",
)

load("@rules_poetry_python3_10//:defs.bzl", python_interpreter = "interpreter")

# install pip and setuptools locally
load("@com_sonia_rules_poetry//rules_poetry:defs.bzl", "poetry_deps")

poetry_deps()



# Go rules to make the Docker rules work

http_archive(
  name = "io_bazel_rules_go",
  sha256 = "099a9fb96a376ccbbb7d291ed4ecbdfd42f6bc822ab77ae6f1b5cb9e914e94fa",
  urls = [
    "https://mirror.bazel.build/github.com/bazelbuild/rules_go/releases/download/v0.35.0/rules_go-v0.35.0.zip",
    "https://github.com/bazelbuild/rules_go/releases/download/v0.35.0/rules_go-v0.35.0.zip",
  ],
)

load("@io_bazel_rules_go//go:deps.bzl", "go_register_toolchains", "go_rules_dependencies")

go_rules_dependencies()

go_register_toolchains(version = "1.19.1")



# Docker rules for testing

http_archive(
    name = "io_bazel_rules_docker",
    sha256 = "b1e80761a8a8243d03ebca8845e9cc1ba6c82ce7c5179ce2b295cd36f7e394bf",
    urls = ["https://github.com/bazelbuild/rules_docker/releases/download/v0.25.0/rules_docker-v0.25.0.tar.gz"],
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
    python_interpreter_target = python_interpreter,
)

poetry(
    name = "test_poetry_no_groups",
    excludes = [
        "enum34",
        "setuptools",
    ],
    lockfile = "//test/no_group_deps:poetry.lock",
    pyproject = "//test/no_group_deps:pyproject.toml",
    python_interpreter_target = python_interpreter,
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
