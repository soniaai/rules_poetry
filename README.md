# Poetry Rules

Poetry is a package manager for Python. Bazel is a build system.
Together they form a powerful, (mostly) hermetic build system for Python.

## Installation

### Prerequisites

* Poetry 1.0 or higher
* Bazel 1.0 or higher

The rules depend on Poetry's current lock file format.
Versions 0.12.x or lower have a different format that is no longer supported.

### Workspace Modifications

Add these lines to your project's `WORKSPACE` file:

```
# Poetry rules for managing Python dependencies

http_archive(
    name = "com_sonia_rules_poetry",
    sha256 = "8a7a6a5d2ef859ba4309929f3b4d61031f2a4bfed6f450f04ab09443246a4b5c",
    strip_prefix = "rules_poetry-ecd0d9c66b89403667304b11da3bd99764797a63",
    urls = ["https://github.com/soniaai/rules_poetry/archive/ecd0d9c66b89403667304b11da3bd99764797a63.tar.gz"],
)

load("@com_sonia_rules_poetry//rules_poetry:defs.bzl", "poetry_deps")

poetry_deps()

load("@com_sonia_rules_poetry//rules_poetry:poetry.bzl", "poetry")

poetry(
    name = "poetry",
    lockfile = "//:poetry.lock",
    pyproject = "//:pyproject.toml",
    # optional, if you would like to pull from pip instead of a Bazel cache
    tags = ["no-remote-cache"],
)
```

and use it to transitively pull in package dependencies using the generated `dependency` macro:

```
load("@poetry//:dependencies.bzl", "dependency")
load("@rules_python//python:defs.bzl", "py_library")

py_library(
    name = "some_package",
    srcs = ["example.py"],
    deps = [
        dependency("pytorch"),
        dependency("tensorflow"),
    ],
)
```

### Usage

Usage is nearly identical to Poetry without Bazel.
To add a dependency just run `poetry add <package name>`.
To remove a package run `poetry remove <package name>`.

## Caveats

* May not work in network isolated sandboxes (untested)
* Cache support is best-effort
* Source wheels are built on demand and may not always produce deterministic results

## Rules Comparison

As you're probably aware, there are a number of Python rules for Bazel due to `rules_python` being insufficient for
many real world applications. While there is significant overlap between these rules, they're not identical in
implementation nor in capability. A feature summary is listed below:

| Feature | rules_poetry | rules_python |
| ---| --- | --- |
| Backend | poetry | pip |
| Incremental | *yes* | no |
| Transitive | *yes* | no |
| Isolation | *yes* | no |
| Hash Validation | *yes* | depends |
| Deterministic | yes | yes |
| Crosstool | no | no |

----
* Backend: which program is used for package management.
* Incremental: adding, upgrading or removing packages only affects those that are modified.
    Unchanged packages are not reinstalled or downloaded.
* Transitive: depending on one package will include all other packages it indirectly depends on.
* Isolation: packages in the system or user site-packages should not be present in Python's path.
* Hash Validation: wheel and source hashes are validated before installation
* Deterministic: builds should be repeatable and cacheable
* Crosstool: cross compilation (target != execution platform)

## TODOs

* [ ] Investiage using `http_file` instead of `pip download` to fetch dependencies
* [ ] Expose the Poetry binary as a Bazel py_binary
* [ ] Generate wrappers named `python3` `python3.7` etc
* [ ] Add the wrappers to the `PATH` so the interpreter entrypoint is consistent
* [ ] Unpack wheels directly into container layers to improve cacheability
* [ ] Improve documentation
* [ ] Write more tests

# Contributions Welcome!
