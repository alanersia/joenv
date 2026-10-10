from src.cli.app import run_cli
from std.sys import exit

def main() raises:
    try:
        run_cli()
    except error:
        print("joenv: error:", error)
        exit(1)
