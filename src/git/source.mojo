from std.collections import List
from std.os import Process
from std.subprocess import run as capture


def safe_name(value: String) -> Bool:
    if value.byte_length() == 0:
        return False
    for index in range(value.byte_length()):
        var c = value[byte=index]
        if not (c >= "a" and c <= "z") and not (c >= "A" and c <= "Z") and not (c >= "0" and c <= "9") and String(c) != "_":
            return False
    return not (value[byte=0] >= "0" and value[byte=0] <= "9")


def _repo_segment(value: String) -> Bool:
    if value.byte_length() == 0 or value == "." or value == "..":
        return False
    for index in range(value.byte_length()):
        var c = value[byte=index]
        if not (c >= "a" and c <= "z") and not (c >= "A" and c <= "Z") and not (c >= "0" and c <= "9") and String(c) != "-" and String(c) != "_" and String(c) != ".":
            return False
    return True


def shell_quote(value: String) -> String:
    var quoted = String("'")
    quoted += value.replace("'", "'\\''")
    quoted += "'"
    return quoted


def _remove_git_suffix(value: String) -> String:
    if value.endswith(".git"):
        return String(value[byte=0:value.byte_length() - 4])
    return value


def normalize_repository(value: String) raises -> String:
    var stripped_input = value.strip()
    var url = String(stripped_input)
    if url.startswith("github.com/"):
        var prefixed = String("https://")
        prefixed += url
        url = prefixed
    if not url.startswith("https://github.com/") or "@" in url or "?" in url or "#" in url:
        raise Error("only public GitHub HTTPS repository URLs are supported")
    var remainder = String(url.removeprefix("https://github.com/"))
    var trimmed = remainder.rstrip("/")
    url = String(trimmed)
    var parts = url.split("/")
    if len(parts) != 2:
        raise Error("expected github.com/owner/repository")
    var owner = String(parts[0])
    var repo = String(parts[1])
    repo = _remove_git_suffix(repo)
    if not _repo_segment(owner) or not _repo_segment(repo):
        raise Error("invalid GitHub repository path")
    return "https://github.com/" + owner.lower() + "/" + repo.lower() + ".git"


def repository_name(canonical_url: String) -> String:
    var parts = canonical_url.split("/")
    return String(parts[len(parts) - 1].removesuffix(".git"))


def run_process(command: String, args: List[String]) raises -> Int:
    var line = shell_quote(command)
    for arg in args:
        line += " " + shell_quote(arg)
    var process = Process.run("sh", ["-c", line])
    var status = process.wait()
    return status.exit_code.value()


def clone_head(url: String, checkout: String) raises -> String:
    var args: List[String] = ["clone", "--", url, checkout]
    var clone_status = run_process("git", args)
    if clone_status != 0:
        raise Error("Git clone failed; check the URL and network access")
    var output = capture("git -C '" + checkout + "' rev-parse HEAD")
    if output.byte_length() != 40 and output.byte_length() != 64:
        raise Error("Git did not return a valid commit SHA")
    return output


def checkout_commit(url: String, commit: String, checkout: String) raises:
    if commit.byte_length() != 40 and commit.byte_length() != 64:
        raise Error("lockfile contains an invalid commit SHA")
    for index in range(commit.byte_length()):
        var c = commit[byte=index]
        if not (c >= "0" and c <= "9") and not (c >= "a" and c <= "f"):
            raise Error("lockfile contains an invalid commit SHA")
    var clone_args: List[String] = ["clone", "--no-checkout", "--", url, checkout]
    if run_process("git", clone_args) != 0:
        raise Error("Git clone failed; check the URL and network access")
    var checkout_args: List[String] = ["-C", checkout, "checkout", "--detach", commit]
    if run_process("git", checkout_args) != 0:
        raise Error("locked commit is unavailable in the repository")
    var output = capture("git -C '" + checkout + "' rev-parse HEAD")
    if output != commit:
        raise Error("Git checkout did not match the locked commit SHA")
