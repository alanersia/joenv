from std.collections import List
from std.os import listdir
from std.pathlib import Path

from src.git.source import safe_name


struct MojoPackage(Copyable):
    var name: String
    var subdir: String
    var source: Path

    def __init__(out self, name: String, subdir: String, source: Path):
        self.name = name
        self.subdir = subdir
        self.source = source


def detect_package(checkout: Path, repo_name: String) raises -> MojoPackage:
    if checkout.joinpath("__init__.mojo").is_file():
        if not safe_name(repo_name):
            raise Error("repository name is not a safe Mojo import name")
        return MojoPackage(repo_name, ".", checkout)
    var expected = checkout.joinpath(repo_name)
    if expected.is_dir() and expected.joinpath("__init__.mojo").is_file():
        if not safe_name(repo_name):
            raise Error("repository name is not a safe Mojo import name")
        return MojoPackage(repo_name, repo_name, expected)

    var candidates = List[MojoPackage]()
    for entry in listdir(checkout):
        var child = checkout.joinpath(entry)
        if child.is_dir() and child.joinpath("__init__.mojo").is_file():
            if not safe_name(entry):
                continue
            candidates.append(MojoPackage(entry, entry, child))
    if len(candidates) == 0:
        raise Error("no Mojo package found; expected a root __init__.mojo or a package subdirectory")
    if len(candidates) > 1:
        raise Error("multiple Mojo packages found; name the desired package directory after the repository")
    return candidates[0].copy()
