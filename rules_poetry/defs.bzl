load("@bazel_tools//tools/build_defs/repo:http.bzl", "http_archive")

def deterministic_env():
    return {
        # lifted from https://github.com/bazelbuild/rules_python/issues/154
        "CFLAGS": "-g0",  # debug symbols contain non-deterministic file paths
        "PATH": "/bin:/usr/bin:/usr/local/bin",
        "PYTHONDONTWRITEBYTECODE": "1",
        "PYTHONHASHSEED": "0",
        "SOURCE_DATE_EPOCH": "315532800",  # set wheel timestamps to 1980-01-01T00:00:00Z
    }

def poetry_deps():
    http_archive(
        name = "pip_archive",
        sha256 = "a810bf07c3723a28621c29abe8e34429fa082c337f89aea9a795865416b66d3e",
        strip_prefix = "pip-21.1",
        urls = ["https://files.pythonhosted.org/packages/de/62/77b8b1a9f9c710988e5a58c22a7cd025b63b204df57a6ea939d6d39da421/pip-21.1.tar.gz"],
        build_file_content = """
load("@rules_python//python:defs.bzl", "py_binary")

py_binary(
    name = "pip",
    main = "src/pip/__main__.py",
    imports = ["src"],
    srcs = glob(["src/**/*.py"]),
    data = glob(["src/**/*"], exclude=["**/*.py", "**/* *", "BUILD", "WORKSPACE"]),
    deps = ["@setuptools_archive//:setuptools", "@wheel_archive//:wheel"],
    python_version = "PY3",
    visibility = ["//visibility:public"],
)
        """,
        workspace_file_content = "",
    )

    http_archive(
        name = "wheel_archive",
        sha256 = "10c9da68765315ed98850f8e048347c3eb06dd81822dc2ab1d4fde9dc9702646",
        strip_prefix = "wheel-0.33.6",
        urls = ["https://files.pythonhosted.org/packages/59/b0/11710a598e1e148fb7cbf9220fd2a0b82c98e94efbdecb299cb25e7f0b39/wheel-0.33.6.tar.gz"],
        build_file_content = """
load("@rules_python//python:defs.bzl", "py_library")

py_library(
    name = "wheel",
    imports = ["wheel"],
    srcs = glob(["wheel/**/*.py"]),
    data = glob(["wheel/**/*"], exclude=["**/*.py", "**/* *", "BUILD", "WORKSPACE"]),
    visibility = ["//visibility:public"],
)
        """,
        workspace_file_content = "",
    )

    http_archive(
        name = "setuptools_archive",
        sha256 = "6afa61b391dcd16cb8890ec9f66cc4015a8a31a6e1c2b4e0c464514be1a3d722",
        urls = ["https://files.pythonhosted.org/packages/11/0a/7f13ef5cd932a107cd4c0f3ebc9d831d9b78e1a0e8c98a098ca17b1d7d97/setuptools-41.6.0.zip"],
        build_file_content = """
load("@rules_python//python:defs.bzl", "py_library")

py_library(
    name = "setuptools",
    imports = ["setuptools"],
    srcs = glob(["setuptools/**/*.py"]),
    data = glob(["setuptools/**/*"], exclude=["**/*.py", "**/* *", "BUILD", "WORKSPACE"]),
    visibility = ["//visibility:public"],
)
        """,
        workspace_file_content = "",
    )

WheelInfo = provider(fields = [
    "pkg",
    "version",
    "marker",
])

def _render_requirements(ctx):
    destination = ctx.actions.declare_file("requirements/%s.txt" % ctx.attr.name)
    marker = ctx.attr.marker
    if marker:
        marker = "; " + marker

    content = "{name}=={version} {hashes} {marker}".format(
        name = ctx.attr.pkg,
        version = ctx.attr.version,
        hashes = " ".join(["--hash=" + h for h in ctx.attr.hashes]),
        marker = marker,
    )
    ctx.actions.write(
        output = destination,
        content = content,
        is_executable = False,
    )

    return destination

COMMON_ARGS = [
    "--quiet",
    "--no-deps",
    "--disable-pip-version-check",
    "--no-cache-dir",
    "--isolated",
]

def _download(ctx, requirements):
    destination = ctx.actions.declare_directory("wheels/%s" % ctx.attr.name)
    toolchain = ctx.toolchains["@bazel_tools//tools/python:toolchain_type"]
    runtime = ctx.toolchains["@bazel_tools//tools/python:toolchain_type"].py3_runtime

    # The Python interpreter can be either provided through a path
    # (platform runtime), or through a label (in-build runtime).
    # See https://docs.bazel.build/versions/master/be/python.html#py_runtime
    if runtime.interpreter_path != None:
        executable = runtime.interpreter_path
        inputs = depset([requirements])
        tools = depset(direct = [ctx.executable._pip])
    else:
        executable = runtime.interpreter.path
        inputs = depset([requirements], transitive = [runtime.files])
        tools = depset(direct = [runtime.interpreter,
                                 ctx.executable._pip], transitive = [runtime.files])

    pip_path = ctx.executable._pip.path
    args = ctx.actions.args()
    if pip_path.endswith(".exe"):
        executable = pip_path
    else:
        args.add(pip_path)
    args.add("wheel")
    args.add_all(COMMON_ARGS)
    args.add("--require-hashes")
    args.add("--wheel-dir")
    args.add(destination.path)
    args.add("-r")
    args.add(requirements)
    if ctx.attr.source_url != "":
        args.add("-i")
        args.add(ctx.attr.source_url)

    ctx.actions.run(
        executable = executable,
        inputs = inputs,
        outputs = [destination],
        arguments = [args],
        env = deterministic_env(),
        mnemonic = "DownloadWheel",
        progress_message = "Collecting %s wheel from pypi" % ctx.attr.pkg,
        execution_requirements = {
            "requires-network": "",
        },
        tools = tools,
    )

    return destination

def _download_wheel_impl(ctx):
    requirements = _render_requirements(ctx)
    wheel_directory = _download(ctx, requirements)

    return [
        DefaultInfo(
            files = depset([wheel_directory]),
            runfiles = ctx.runfiles(
                files = [wheel_directory],
                collect_default = True,
            ),
        ),
        WheelInfo(
            pkg = ctx.attr.pkg,
            version = ctx.attr.version,
            marker = ctx.attr.marker,
        ),
    ]

download_wheel = rule(
    implementation = _download_wheel_impl,
    attrs = {
        "_pip": attr.label(default = "@pip_archive//:pip", executable = True, cfg = "host"),
        "pkg": attr.string(mandatory = True),
        "version": attr.string(mandatory = True),
        "hashes": attr.string_list(mandatory = True, allow_empty = False),
        "marker": attr.string(mandatory = True),
        "source_url": attr.string(mandatory = True)
    },
    toolchains = ["@bazel_tools//tools/python:toolchain_type"],
)

def _install(ctx, wheel_info):
    installed_wheel = ctx.actions.declare_directory(wheel_info.pkg)

    # work around dumb distutils "feature" that prevents using `pip install --target
    # if a system config file already has a prefix setup... such as homebrew's
    # copy in /usr/local/opt/python3/Frameworks/Python.framework/Versions/3.7/lib/python3.7/distutils/distutils.cfg
    # the second portion of this sets the HOME environment variable to this directory
    # so distutils will pick it up instead of Homebrew's broken version
    setup_cfg = ctx.actions.declare_file("distutils_config/.pydistutils.cfg")
    ctx.actions.write(
        setup_cfg,
        """
[install]
prefix=
""",
    )

    toolchain = ctx.toolchains["@bazel_tools//tools/python:toolchain_type"]
    runtime = ctx.toolchains["@bazel_tools//tools/python:toolchain_type"].py3_runtime

    # The Python interpreter can be either provided through a path
    # (platform runtime), or through a label (in-build runtime).
    # See https://docs.bazel.build/versions/master/be/python.html#py_runtime
    if runtime.interpreter_path != None:
        interpreter_path = runtime.interpreter_path
        tools = depset(direct = [ctx.executable._pip])
    else:
        interpreter_path = runtime.interpreter.path
        tools = depset(direct = [runtime.interpreter,
                                 ctx.executable._pip], transitive = [runtime.files])

    executable = [ctx.executable._pip.path]
    if not ctx.executable._pip.path.endswith(".exe"):
        executable.insert(0, interpreter_path)

    args = ctx.actions.args()
    args.add(" ".join(executable))
    args.add(" ".join(COMMON_ARGS))
    args.add(installed_wheel.path)
    args.add(wheel_info.marker)

    # bazel expands the directory to individual files
    args.add_all(ctx.files.wheel)

    ctx.actions.run_shell(
        command = "$1 install --force-reinstall --upgrade $2 --no-compile --target=$3 \"$5 ; $4\"",
        # second portion of the .pydistutils.cfg workaround described above
        env = dict(deterministic_env().items() + [("HOME", setup_cfg.dirname)]),
        inputs = ctx.files.wheel + [setup_cfg],
        outputs = [installed_wheel],
        progress_message = "Installing %s wheel" % wheel_info.pkg,
        arguments = [args],
        mnemonic = "CopyWheel",
        tools = tools,
    )

    return installed_wheel

def _pip_install_impl(ctx):
    w = ctx.attr.wheel
    wheel_info = w[WheelInfo]
    wheel = _install(ctx, wheel_info)

    return [
        DefaultInfo(
            files = depset([wheel]),
            runfiles = ctx.runfiles(
                files = [wheel],
                collect_default = True,
            ),
        ),
        PyInfo(
            transitive_sources = depset([wheel]),
        ),
    ]

pip_install = rule(
    implementation = _pip_install_impl,
    attrs = {
        "_pip": attr.label(default = "@pip_archive//:pip", executable = True, cfg = "host"),
        "wheel": attr.label(mandatory = True, providers = [WheelInfo]),
    },
    toolchains = ["@bazel_tools//tools/python:toolchain_type"],
)

def _noop_impl(ctx):
    return []

noop = rule(
    implementation = _noop_impl,
    doc = "Rule for excluded packages",
)
