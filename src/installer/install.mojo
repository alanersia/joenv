from std.os import makedirs
from std.pathlib import Path
from std.subprocess import run as capture
from std.tempfile import TemporaryDirectory

from src.git.source import run_process, checkout_commit, shell_quote, repository_name
from src.resolver.package import detect_package


def _copy_package(source: Path, destination: Path) raises:
    if run_process("cp", ["-R", "--", source.path, destination.path]) != 0 or not destination.exists():
        raise Error("copying the Mojo package failed")


def install_checkout(root: Path, name: String, checkout: Path, subdir: String) raises:
    var source = checkout
    if subdir != ".":
        var unsafe = subdir.startswith("/")
        for part in subdir.split("/"):
            if String(part) == "..":
                unsafe = True
        if unsafe:
            raise Error("unsafe package subdirectory in lockfile")
        source = checkout.joinpath(subdir)
    if not source.joinpath("__init__.mojo").is_file():
        raise Error("selected package directory has no __init__.mojo")
    var links = capture("git -C " + shell_quote(checkout.path) + " ls-tree -r HEAD")
    if "120000 blob" in links:
        raise Error("repository contains symbolic links; v0.1 refuses to install them")
    var packages = root.joinpath("mojo_packages").joinpath("packages")
    makedirs(packages.path, exist_ok=True)
    var destination = packages.joinpath(name)
    var temp = TemporaryDirectory(prefix="joenv-stage-")
    var stage_root = Path(temp.name)
    var staged = stage_root.joinpath("package")
    _copy_package(source, staged)
    var backup = stage_root.joinpath("previous")
    if destination.exists():
        if run_process("mv", ["-f", "--", destination.path, backup.path]) != 0 or not backup.exists():
            raise Error("could not stage the previous package for replacement")
    var move_status = run_process("mv", ["-f", "--", staged.path, destination.path])
    if move_status != 0:
        if backup.exists():
            _ = run_process("mv", ["-f", "--", backup.path, destination.path])
        raise Error("package installation failed; the previous installation was restored")
    if not destination.exists():
        if backup.exists():
            _ = run_process("mv", ["-f", "--", backup.path, destination.path])
        raise Error("package installation failed; the previous installation was restored")


def install_pinned(root: Path, name: String, url: String, commit: String, subdir: String) raises:
    var temp = TemporaryDirectory(prefix="joenv-checkout-")
    var checkout = Path(temp.name).joinpath("checkout")
    checkout_commit(url, commit, checkout.path)
    var package = detect_package(checkout, repository_name(url))
    if package.name != name or package.subdir != subdir:
        raise Error("lockfile package identity does not match the pinned repository")
    install_checkout(root, name, checkout, subdir)
