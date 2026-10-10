from std.collections import List
from std.pathlib import Path

from src.git.source import normalize_repository, run_process, safe_name


struct Dependency(Copyable):
    var name: String
    var git: String
    var commit: String
    var subdir: String

    def __init__(out self, name: String, git: String, commit: String = "", subdir: String = ""):
        self.name = name
        self.git = git
        self.commit = commit
        self.subdir = subdir


struct Manifest(Copyable):
    var name: String
    var version: String
    var dependencies: List[Dependency]

    def __init__(out self, name: String, version: String):
        self.name = name
        self.version = version
        self.dependencies = List[Dependency]()


def _parse_string(raw: String) raises -> String:
    if raw.byte_length() < 2 or not raw.startswith("\"") or not raw.endswith("\""):
        raise Error("expected a quoted string")
    var value = String(raw[byte=1:raw.byte_length() - 1])
    if "\"" in value or "\\" in value:
        raise Error("escaped TOML strings are unsupported in v0.1")
    return value


def _valid_project_name(value: String) -> Bool:
    if value.byte_length() == 0 or value == "." or value == "..":
        return False
    if not safe_name(String(value[byte=0])):
        return False
    for index in range(value.byte_length()):
        var c = String(value[byte=index])
        if not (c >= "a" and c <= "z") and not (c >= "A" and c <= "Z") and not (c >= "0" and c <= "9") and c != "-" and c != "_" and c != ".":
            return False
    return True


def _valid_version(value: String) -> Bool:
    if value.byte_length() == 0:
        return False
    for index in range(value.byte_length()):
        var c = String(value[byte=index])
        if not (c >= "a" and c <= "z") and not (c >= "A" and c <= "Z") and not (c >= "0" and c <= "9") and c != "." and c != "+" and c != "-":
            return False
    return True


def parse_manifest(text: String) raises -> Manifest:
    var manifest = Manifest("", "")
    var section = String("")
    for raw_line in text.splitlines():
        var line = String(raw_line.strip())
        if not line or line.startswith("#"):
            continue
        if line == "[package]":
            section = "package"
            continue
        if line == "[dependencies]":
            section = "dependencies"
            continue
        var parts = line.split("=", maxsplit=1)
        if len(parts) != 2:
            raise Error("invalid joenv.toml assignment")
        var key = String(parts[0].strip())
        var value = String(parts[1].strip())
        if section == "package":
            if key == "name":
                manifest.name = _parse_string(value)
            elif key == "version":
                manifest.version = _parse_string(value)
            else:
                raise Error("unsupported field in [package]")
        elif section == "dependencies":
            if not safe_name(key):
                raise Error("unsafe dependency package name")
            if not value.startswith("{") or not value.endswith("}"):
                raise Error("v0.1 supports only { git = \"...\" } dependencies")
            var inner = String(value[byte=1:value.byte_length() - 1])
            var items = inner.split(",")
            var url = String("")
            for item in items:
                var field = String(item).split("=", maxsplit=1)
                if len(field) != 2 or String(field[0].strip()) != "git" or url:
                    raise Error("v0.1 supports only one git field per dependency")
                url = normalize_repository(_parse_string(String(field[1].strip())))
            if not url:
                raise Error("Git dependency is missing its git URL")
            manifest.dependencies.append(Dependency(key, url))
        else:
            raise Error("joenv.toml keys must be inside [package] or [dependencies]")
    if not _valid_project_name(manifest.name) or not _valid_version(manifest.version):
        raise Error("joenv.toml [package] requires name and version")
    return manifest^


def parse_lock(text: String) raises -> List[Dependency]:
    var result = List[Dependency]()
    var section = String("")
    var format_seen = False
    for raw_line in text.splitlines():
        var line = String(raw_line.strip())
        if not line or line.startswith("#"):
            continue
        if line == "[dependencies]":
            section = "dependencies"
            continue
        var parts = line.split("=", maxsplit=1)
        if len(parts) != 2:
            raise Error("invalid joenv.lock assignment")
        var key = String(parts[0].strip())
        var value = String(parts[1].strip())
        if not section:
            if key != "format" or value != "1" or format_seen:
                raise Error("unsupported joenv.lock format")
            format_seen = True
            continue
        if section != "dependencies" or not safe_name(key):
            raise Error("invalid lock dependency name")
        if not value.startswith("{") or not value.endswith("}"):
            raise Error("invalid locked dependency")
        var inner = String(value[byte=1:value.byte_length() - 1])
        var fields = inner.split(",")
        var url = String("")
        var commit = String("")
        var subdir = String("")
        for item in fields:
            var field = String(item).split("=", maxsplit=1)
            if len(field) != 2:
                raise Error("malformed locked dependency")
            var field_name = String(field[0].strip())
            var field_value = _parse_string(String(field[1].strip()))
            if field_name == "git":
                url = normalize_repository(field_value)
            elif field_name == "commit":
                commit = field_value
            elif field_name == "subdir":
                subdir = field_value
            else:
                raise Error("unsupported locked dependency field")
        if not url or not commit or not subdir:
            raise Error("locked dependency requires git, commit, and subdir")
        result.append(Dependency(key, url, commit, subdir))
    if not format_seen:
        raise Error("joenv.lock requires format = 1")
    return result^


def read_manifest(root: Path) raises -> Manifest:
    var path = root / "joenv.toml"
    if not path.is_file():
        raise Error("joenv.toml not found; run `joenv init` first")
    return parse_manifest(path.read_text())


def read_lock(root: Path) raises -> List[Dependency]:
    var path = root / "joenv.lock"
    if not path.is_file():
        raise Error("joenv.lock not found; run `joenv add` for each dependency first")
    return parse_lock(path.read_text())


def upsert(mut items: List[Dependency], item: Dependency):
    for index in range(len(items)):
        if items[index].name == item.name:
            items[index] = item.copy()
            return
    items.append(item.copy())


def manifest_text(manifest: Manifest) -> String:
    var output = String("[package]\nname = \"")
    output += manifest.name + "\"\nversion = \"" + manifest.version + "\"\n\n[dependencies]\n"
    for dep in manifest.dependencies:
        output += dep.name + " = { git = \"" + dep.git + "\" }\n"
    return output


def lock_text(items: List[Dependency]) -> String:
    var output = String("format = 1\n\n[dependencies]\n")
    for dep in items:
        output += dep.name + " = { git = \"" + dep.git + "\", commit = \"" + dep.commit + "\", subdir = \"" + dep.subdir + "\" }\n"
    return output


def write_project(root: Path, manifest: Manifest, lock: List[Dependency]) raises:
    var manifest_temp = root / ".joenv.toml.tmp"
    var lock_temp = root / ".joenv.lock.tmp"
    manifest_temp.write_text(manifest_text(manifest))
    lock_temp.write_text(lock_text(lock))
    var manifest_dest = root.joinpath("joenv.toml")
    var lock_dest = root.joinpath("joenv.lock")
    if run_process("mv", ["-f", "--", manifest_temp.path, manifest_dest.path]) != 0:
        raise Error("could not replace joenv.toml")
    if run_process("mv", ["-f", "--", lock_temp.path, lock_dest.path]) != 0:
        raise Error("could not replace joenv.lock")
    if not manifest_dest.is_file() or not lock_dest.is_file():
        raise Error("could not atomically update Joenv manifest and lockfile")


def initialize(root: Path) raises:
    if (root / "joenv.toml").exists():
        raise Error("joenv.toml already exists")
    from std.os import makedirs
    makedirs(root.joinpath("src").path, exist_ok=True)
    makedirs(root.joinpath("mojo_packages").joinpath("packages").path, exist_ok=True)
    var path_name = root.path.split("/")
    var name = String(path_name[len(path_name) - 1])
    if not _valid_project_name(name):
        name = "my-app"
    var manifest = Manifest(name, "0.1.0")
    var lock = List[Dependency]()
    write_project(root, manifest, lock)
    var main = root.joinpath("src").joinpath("main.mojo")
    if not main.exists():
        main.write_text('def main():\n    print("Hello from Mojo")\n')
