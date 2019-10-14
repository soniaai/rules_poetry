WheelInfo = provider(fields = [
    "pkg",
    "version",
    "marker",
])

def _py_interpreter(ctx):
    toolchain = ctx.toolchains["@bazel_tools//tools/python:toolchain_type"]
    return toolchain.py3_runtime.interpreter_path or toolchain.py3_runtime.interpreter

def _py_files(ctx):
    toolchain = ctx.toolchains["@bazel_tools//tools/python:toolchain_type"]
    return toolchain.py3_runtime.files or []

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

def _download(ctx, requirements):
    interpreter = _py_interpreter(ctx)
    destination = ctx.actions.declare_directory("wheels/%s" % ctx.attr.name)
    args = ctx.actions.args()
    args.add("-m")
    args.add("pip")
    args.add("wheel")
    args.add("--quiet")
    args.add("--no-deps")
    args.add("--require-hashes")
    args.add("--disable-pip-version-check")
    args.add("--no-cache-dir")
    args.add("--isolated")
    args.add("--wheel-dir")
    args.add(destination.path)
    args.add("-r")
    args.add(requirements)

    ctx.actions.run(
        executable = interpreter,
        inputs = [requirements],
        outputs = [destination],
        arguments = [args],
        use_default_shell_env = True,  # we need access to PATH
        mnemonic = "DownloadWheel",
        progress_message = "Collecting %s wheel from pypi" % ctx.attr.pkg,
        execution_requirements = {
            "requires-network": "",
        },
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
        "pkg": attr.string(mandatory = True),
        "version": attr.string(mandatory = True),
        "hashes": attr.string_list(mandatory = True, allow_empty = False),
        "marker": attr.string(mandatory = True),
    },
    toolchains = ["@bazel_tools//tools/python:toolchain_type"],
    fragments = ["py"],
    # TODO(nathan): add python fragment dependency to get current python version
    # instead of assuming/hardcoding it to python3... but no
    # nothing on PythonConfiguration is callable from skylark :(
)

def _install(ctx, wheel_info):
    interpreter = _py_interpreter(ctx)
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

    args = ctx.actions.args()
    args.add(interpreter)
    args.add(installed_wheel.path)
    args.add(wheel_info.marker)
    # bazel expands the directory to individual files
    args.add_all(ctx.files.wheel)

    ctx.actions.run_shell(
        command = "$1 -m pip install --force-reinstall --upgrade --no-deps --quiet --disable-pip-version-check --no-cache-dir --target=$2 \"$4 ; $3\"",
        # second portion of the .pydistutils.cfg workaround described above
        env = {"HOME": setup_cfg.dirname},
        inputs = ctx.files.wheel + [setup_cfg],
        outputs = [installed_wheel],
        progress_message = "Installing %s wheel" % wheel_info.pkg,
        arguments = [args],
        mnemonic = "CopyWheel",
        tools = depset(direct = [_py_interpreter(ctx)], transitive = _py_files(ctx)),
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
        "wheel": attr.label(mandatory = True, providers = [WheelInfo]),
    },
    toolchains = ["@bazel_tools//tools/python:toolchain_type"],
)
