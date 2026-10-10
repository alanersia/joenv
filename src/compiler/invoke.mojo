from std.collections import List
from std.os import Process
from std.pathlib import Path
from src.git.source import shell_quote


def invoke(command: String, args: List[String]) raises -> Int:
    if len(args) == 0:
        raise Error("usage: joenv " + command + " <source.mojo> [arguments]")
    var compiler_command = String("mojo ") + shell_quote(command) + " -I " + shell_quote(Path().joinpath("mojo_packages").joinpath("packages").path)
    for arg in args:
        compiler_command += " " + shell_quote(arg)
    var process = Process.run("sh", ["-c", compiler_command])
    var status = process.wait()
    return status.exit_code.value()
