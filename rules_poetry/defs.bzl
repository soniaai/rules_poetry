load("@bazel_tools//tools/build_defs/repo:http.bzl", "http_archive")

def poetry_deps():
    http_archive(
        name = "pip_archive",
        sha256 = "21207d76c1031e517668898a6b46a9fb1501c7a4710ef5dfd6a40ad9e6757ea7",
        strip_prefix = "pip-19.3.1",
        urls = ["https://files.pythonhosted.org/packages/ce/ea/9b445176a65ae4ba22dce1d93e4b5fe182f953df71a145f557cffaffc1bf/pip-19.3.1.tar.gz"],
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
    imports = ["src"],
    srcs = glob(["wheel/**/*.py"]),
    data = glob(["wheel/**/*"], exclude=["**/*.py", "**/* *", "BUILD", "WORKSPACE"]),
    visibility = ["//visibility:public"],
)
        """,
        workspace_file_content = "",
    )

    http_archive(
        name = "setuptools_archive",
        sha256 = "3e8e8505e563631e7cb110d9ad82d135ee866b8146d5efe06e42be07a72db20a",
        urls = ["https://files.pythonhosted.org/packages/11/0a/7f13ef5cd932a107cd4c0f3ebc9d831d9b78e1a0e8c98a098ca17b1d7d97/setuptools-41.6.0.zip"],
        build_file_content = """
load("@rules_python//python:defs.bzl", "py_library")

py_library(
    name = "setuptools",
    imports = ["src"],
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

def _download(ctx, requirements):
    destination = ctx.actions.declare_directory("wheels/%s" % ctx.attr.name)
    args = ctx.actions.args()
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
        executable = ctx.executable._pip,
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
        "_pip": attr.label(default = "@pip_archive//:pip", executable = True, cfg = "host"),
        "pkg": attr.string(mandatory = True),
        "version": attr.string(mandatory = True),
        "hashes": attr.string_list(mandatory = True, allow_empty = False),
        "marker": attr.string(mandatory = True),
    },
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

    args = ctx.actions.args()
    args.add(ctx.executable._pip)
    args.add(installed_wheel.path)
    args.add(wheel_info.marker)

    # bazel expands the directory to individual files
    args.add_all(ctx.files.wheel)

    ctx.actions.run_shell(
        command = "$1 install --force-reinstall --upgrade --no-deps --quiet --disable-pip-version-check --no-cache-dir --target=$2 \"$4 ; $3\"",
        # second portion of the .pydistutils.cfg workaround described above
        env = {"HOME": setup_cfg.dirname},
        inputs = ctx.files.wheel + [setup_cfg],
        outputs = [installed_wheel],
        progress_message = "Installing %s wheel" % wheel_info.pkg,
        arguments = [args],
        mnemonic = "CopyWheel",
        tools = [ctx.executable._pip],
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
)

def _noop_impl(ctx):
    return []

noop = rule(
    implementation = _noop_impl,
    doc = "Rule for excluded packages",
)
