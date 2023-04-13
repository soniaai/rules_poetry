"Poetry utility functions"

# Because Poetry doesn't add several packages in the poetry.lock file,
# they are excluded from the list of packages.
# See https://github.com/python-poetry/poetry/blob/d2fd581c9a856a5c4e60a25acb95d06d2a963cf2/poetry/puzzle/provider.py#L55
# and https://github.com/python-poetry/poetry/issues/1584
POETRY_UNSAFE_PACKAGES = ["setuptools", "distribute", "pip", "wheel"]

def _clean_name(name):
    return name.lower().replace("-", "_").replace(".", "_")

def _get_python_interpreter_attr(rctx):
    if rctx.attr.python_interpreter:
        return rctx.attr.python_interpreter

    if "win" in rctx.os.name:
        return "python.exe"
    else:
        return "python3"

def _resolve_python_interpreter(rctx):
    python_interpreter = _get_python_interpreter_attr(rctx)

    if rctx.attr.python_interpreter_target:
        if rctx.attr.python_interpreter:
            fail("python_interpreter_target and python_interpreter incompatible")

        target = rctx.attr.python_interpreter_target
        python_interpreter = rctx.path(target)

        return python_interpreter

    if "/" not in python_interpreter:
        python_interpreter = rctx.which(python_interpreter)

    if not python_interpreter:
        fail("python interpreter `{}` not found in PATH".format(python_interpreter))

    return python_interpreter

def _mapping(repository_ctx):
    python_interpreter = _resolve_python_interpreter(repository_ctx)
    result = repository_ctx.execute(
        [
            python_interpreter,
            repository_ctx.path(repository_ctx.attr._script),
            "-i",
            repository_ctx.path(repository_ctx.attr.pyproject),
            "-o",
            "-",
            "--if",
            "toml",
            "--of",
            "json",
        ],
    )

    if result.return_code:
        fail("remarshal failed: %s (%s)" % (result.stdout, result.stderr))

    pyproject = json.decode(result.stdout)

    def unpack_dependencies(x):
        return {
            dep.lower(): "@%s//:library_%s" % (repository_ctx.name, _clean_name(dep))
            for dep in x.keys()
        }

    dependencies = unpack_dependencies(pyproject["tool"]["poetry"]["dependencies"])

    groups = {}

    
    for k, v in pyproject["tool"]["poetry"].get("group", {}).items():
        groups.update({
            k: unpack_dependencies(v["dependencies"])
        })

    return {
        "dependencies": dependencies,
        "groups": groups,
    }

def _impl(repository_ctx):
    python_interpreter = _resolve_python_interpreter(repository_ctx)
    mapping = _mapping(repository_ctx)

    result = repository_ctx.execute(
        [
            python_interpreter,
            repository_ctx.path(repository_ctx.attr._script),
            "-i",
            repository_ctx.path(repository_ctx.attr.lockfile),
            "-o",
            "-",
            "--if",
            "toml",
            "--of",
            "json",
        ],
    )

    if result.return_code:
        fail("remarshal failed: %s (%s)" % (result.stdout, result.stderr))

    lockfile = json.decode(result.stdout)
    metadata = lockfile["metadata"]
    if "files" in metadata:  # Poetry 1.x format
        files = metadata["files"]

        # only the hashes are needed to build a requirements.txt
        hashes = {
            k: [x["hash"] for x in v]
            for k, v in files.items()
        }
    elif "hashes" in metadata:  # Poetry 0.x format
        hashes = ["sha256:" + h for h in metadata["hashes"]]
    elif metadata["lock-version"] in ["2.0"]:
        hashes = {}
        for package in lockfile["package"]:
            key = package["name"]
            hashes[key] = [pack["hash"] for pack in package["files"]]
    else:
        fail("Did not find file hashes in poetry.lock file")

    # using a `dict` since there is no `set` type
    excludes = {x.lower(): True for x in repository_ctx.attr.excludes + POETRY_UNSAFE_PACKAGES}
    for requested in mapping:
        if requested.lower() in excludes:
            fail("pyproject.toml dependency {} is also in the excludes list".format(requested))

    packages = []
    for package in lockfile["package"]:
        name = package["name"]

        if name.lower() in excludes:
            continue

        if "source" in package and package["source"]["type"] != "legacy":
            # TODO: figure out how to deal with git and directory refs
            print("Skipping " + name)
            continue

        packages.append(struct(
            name = _clean_name(name),
            pkg = name,
            version = package["version"],
            hashes = hashes[name],
            marker = package.get("marker", None),
            source_url = package.get("source", {}).get("url", None),
            dependencies = [
                _clean_name(name)
                for name in package.get("dependencies", {}).keys()
                if name.lower() not in excludes
            ],
        ))

    repository_ctx.file(
        "dependencies.bzl",
        """
_mapping = {mapping}

def dependency(name, group = None):
    if group:
        if group not in _mapping["groups"]:
            fail("%s is not a group in pyproject.toml" % name)

        dependencies = _mapping["groups"][group]

        if name not in dependencies:
            fail("%s is not present in group %s in pyproject.toml" % (name, group))

        return dependencies[name]

    dependencies = _mapping["dependencies"]

    if name not in dependencies:
        fail("%s is not present in pyproject.toml" % name)

    return dependencies[name]
""".format(mapping = mapping),
    )

    repository_ctx.symlink(repository_ctx.path(repository_ctx.attr._rules), repository_ctx.path("defs.bzl"))

    poetry_template = """
download_wheel(
    name = "wheel_{name}",
    pkg = "{pkg}",
    version = "{version}",
    hashes = {hashes},
    marker = "{marker}",
    source_url = "{source_url}",
    visibility = ["//visibility:private"],
    tags = [{download_tags}, "requires-network"],
)

pip_install(
    name = "install_{name}",
    wheel = ":wheel_{name}",
    tags = [{install_tags}],
)

py_library(
    name = "library_{name}",
    srcs = glob(["{pkg}/**/*.py"]),
    data = glob(["{pkg}/**/*"], exclude=["**/*.py", "**/* *", "BUILD", "WORKSPACE"]),
    imports = ["{pkg}"],
    deps = {dependencies},
    visibility = ["//visibility:public"],
)
"""

    build_content = """
load("//:defs.bzl", "download_wheel")
load("//:defs.bzl", "noop")
load("//:defs.bzl", "pip_install")
"""

    install_tags = ["\"{}\"".format(tag) for tag in repository_ctx.attr.tags]
    download_tags = install_tags + ["\"requires-network\""]

    for package in packages:
        # Bazel's built-in json decoder removes string escapes, so we need to
        # make sure that " characters are replaced with ' if they're wrapped
        # in quotes in the template
        if package.marker:
            marker = package.marker.replace('"', "'")
        else:
            marker = ""
        build_content += poetry_template.format(
            name = _clean_name(package.name),
            pkg = package.pkg,
            version = package.version,
            hashes = package.hashes,
            marker = marker,
            source_url = package.source_url or "",
            install_tags = ", ".join(install_tags),
            download_tags = ", ".join(download_tags),
            dependencies = [":install_%s" % _clean_name(package.name)] +
                           [":library_%s" % _clean_name(dep) for dep in package.dependencies],
        )

    excludes_template = """
noop(
    name = "library_{name}",
)
    """

    for package in excludes:
        build_content += excludes_template.format(
            name = _clean_name(package),
        )

    repository_ctx.file("BUILD", build_content)

poetry = repository_rule(
    attrs = {
        "pyproject": attr.label(
            mandatory = True,
            allow_single_file = True,
        ),
        "lockfile": attr.label(
            mandatory = True,
            allow_single_file = True,
        ),
        "excludes": attr.string_list(
            mandatory = False,
            allow_empty = True,
            default = [],
            doc = "List of packages to exclude, useful for skipping invalid dependencies",
        ),
        "python_interpreter": attr.string(
            mandatory = False,
            doc = "The command to run the Python interpreter used during repository setup",
        ),
        "python_interpreter_target": attr.label(
            mandatory = False,
            doc = "The target of the Python interpreter used during repository setup",
        ),
        "_rules": attr.label(
            default = ":defs.bzl",
        ),
        "_script": attr.label(
            executable = True,
            default = "//tools:remarshal.par",
            cfg = "exec",
        ),
    },
    implementation = _impl,
    local = False,
)
