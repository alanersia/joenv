from std.collections import List
from std.pathlib import Path
from std.sys import argv, exit
from std.tempfile import TemporaryDirectory

from src.compiler.invoke import invoke
from src.config.manifest import Dependency, Manifest, initialize, read_lock, read_manifest, upsert, write_project
from src.git.source import clone_head, normalize_repository, repository_name
from src.installer.install import install_checkout, install_pinned
from src.resolver.package import detect_package


def _find(items: List[Dependency], name: String) -> Int:
    for index in range(len(items)):
        if items[index].name == name:
            return index
    return -1


def _add(root: Path, raw_url: String) raises:
    var manifest = read_manifest(root)
    var lock = read_lock(root)
    for dep in manifest.dependencies:
        var index = _find(lock, dep.name)
        if index < 0 or lock[index].git != dep.git:
            raise Error("joenv.toml and joenv.lock disagree; repair dependencies before adding another package")
    if len(lock) != len(manifest.dependencies):
        raise Error("joenv.toml and joenv.lock contain different dependencies")
    var url = normalize_repository(raw_url)
    var temp = TemporaryDirectory(prefix="joenv-add-")
    var checkout = Path(temp.name).joinpath("checkout")
    var commit = clone_head(url, checkout.path)
    var package = detect_package(checkout, repository_name(url))
    var installed = _find(manifest.dependencies, package.name)
    if installed >= 0 and manifest.dependencies[installed].git != url:
        raise Error("Mojo package name is already used by another Git repository")
    install_checkout(root, package.name, checkout, package.subdir)
    upsert(manifest.dependencies, Dependency(package.name, url))
    upsert(lock, Dependency(package.name, url, commit, package.subdir))
    write_project(root, manifest, lock)
    print("Added", package.name, "from", url, "at", commit)


def _install(root: Path) raises:
    var manifest = read_manifest(root)
    var lock = read_lock(root)
    if len(manifest.dependencies) != len(lock):
        raise Error("joenv.toml and joenv.lock contain different dependencies; run `joenv add <github-repository>`")
    for dep in manifest.dependencies:
        var index = _find(lock, dep.name)
        if index < 0 or lock[index].git != dep.git:
            raise Error("joenv.toml and joenv.lock disagree; run `joenv add <github-repository>`")
        install_pinned(root, dep.name, dep.git, lock[index].commit, lock[index].subdir)
        print("Installed", dep.name, "at", lock[index].commit)


def _run(command: String, args: List[String]) raises -> Int:
    return invoke(command, args)


def run_cli() raises:
    var args = argv()
    if len(args) < 2:
        print("Usage: joenv <init|add|install|run|build> [arguments]")
        exit(2)
    var command = String(args[1])
    var root = Path()
    if command == "init":
        initialize(root)
        print("Initialized Joenv project in", root.path)
        return
    if command == "add":
        if len(args) != 3:
            raise Error("usage: joenv add github.com/owner/repository")
        _add(root, String(args[2]))
        return
    if command == "install":
        _install(root)
        return
    if command == "run" or command == "build":
        var compiler_args = List[String]()
        for index in range(2, len(args)):
            compiler_args.append(String(args[index]))
        exit(_run(command, compiler_args))
    if command == "--help" or command == "-h" or command == "help":
        print("Usage: joenv <init|add|install|run|build> [arguments]")
        return
    raise Error("unknown command: " + command)
