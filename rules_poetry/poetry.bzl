load(":json_parser.bzl", "json_parse")

def _clean_name(name):
    return name.lower().replace("-", "_dash_").replace(".", "_dot_")

def _mapping(repository_ctx):
    result = repository_ctx.execute(
        [
            repository_ctx.path(repository_ctx.attr._script),
            "-i",
            repository_ctx.path(repository_ctx.attr.pyproject),
            "-o",
            "/dev/stdout",
            "--if",
            "toml",
            "--of",
            "json",
        ],
    )

    if result.return_code:
        fail("remarshal failed: %s (%s)" % (result.stdout, result.stderr))

    pyproject = json_parse(result.stdout)
    return {
        dep.lower(): "@%s//:%s_library" % (repository_ctx.name, _clean_name(dep))
        for dep in pyproject["tool"]["poetry"]["dependencies"].keys()
    }

def _impl(repository_ctx):
    mapping = _mapping(repository_ctx)

    result = repository_ctx.execute(
        [
            repository_ctx.path(repository_ctx.attr._script),
            "-i",
            repository_ctx.path(repository_ctx.attr.lockfile),
            "-o",
            "/dev/stdout",
            "--if",
            "toml",
            "--of",
            "json",
        ],
    )

    if result.return_code:
        fail("remarshal failed: %s (%s)" % (result.stdout, result.stderr))

    lockfile = json_parse(result.stdout)
    hashes = lockfile["metadata"]["hashes"]
    packages = []
    for package in lockfile["package"]:
        name = package["name"]

        if "source" in package:
            # TODO: figure out how to deal with git and directory refs
            print("Skipping " + name)
            continue

        packages.append(struct(
            name = _clean_name(name),
            pkg = name,
            version = package["version"],
            hashes = hashes[name],
            dependencies = [
                _clean_name(name)
                for name in package.get("dependencies", {}).keys()
                # TODO: hack... remove enum34
                if name.lower() not in ["setuptools", "enum34"]
            ],
        ))

    repository_ctx.file(
        "dependencies.bzl",
        """
_mapping = {mapping}

def dependency(name):
    if name not in _mapping:
        fail("%s is not present in pyproject.toml" % name)

    return _mapping[name]
""".format(mapping = mapping),
    )

    repository_ctx.symlink(repository_ctx.path(repository_ctx.attr._rules), repository_ctx.path("defs.bzl"))

    poetry_template = """
download_wheel(
    name = "{name}_wheel",
    # requirements = ":{name}_requirements",
    pkg = "{pkg}",
    version = "{version}",
    hashes = {hashes},
    visibility = ["//visibility:private"],
)

pip_install(
    name = "{name}_install",
    wheel = ":{name}_wheel",
)

py_library(
    name = "{name}_library",
    srcs = [],
    imports = ["{pkg}"],
    deps = {dependencies},
    visibility = ["//visibility:public"],
)
"""

    build_content = """
load("//:defs.bzl", "download_wheel")
load("//:defs.bzl", "pip_install")
"""

    for package in packages:
        build_content += poetry_template.format(
            name = package.name,
            pkg = package.pkg,
            version = package.version,
            hashes = package.hashes,
            dependencies = [":%s_install" % package.name] +
                           [":%s_library" % dep for dep in package.dependencies],
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
        "_rules": attr.label(
            default = ":defs.bzl",
        ),
        "_script": attr.label(
            executable = True,
            default = "//tools:remarshal.par",
            cfg = "host",
        ),
    },
    implementation = _impl,
    local = False,
)
