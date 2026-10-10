# Architecture

Joenv v0.1 is a Mojo CLI split into small modules for command dispatch,
manifest parsing, Git source retrieval, package detection, installation, and
compiler invocation. The `joenv` shell launcher runs `src/main.mojo` with Mojo.
The source launcher requires Mojo and Git on `PATH`; installed consumer
programs do not link to Joenv or acquire a Python runtime dependency. `sh
install.sh` builds the CLI to a native executable and installs it under
`~/.local/bin` by default, so users can invoke it from any project directory.

## Installation flow

1. Normalize supported GitHub inputs to one HTTPS URL.
2. Clone to a temporary checkout and read its `HEAD` commit.
3. Find a package at repository root, in a directory matching the repository,
   or in the sole top-level directory containing `__init__.mojo`.
4. Require a safe import name and `__init__.mojo`; reject ambiguous candidates.
5. Copy only that package directory through a staging directory into
   `mojo_packages/packages/<import-name>/`.
6. Write the manifest and commit lock metadata.

`joenv install` checks out the locked commit detached, redetects the package,
and verifies the recorded import name and subdirectory before installation.
Joenv never invokes repository setup scripts. Tracked symlinks are rejected.

## Compiler and imports

The Mojo compiler and runtime compile and execute `.mojo` programs. Joenv is a
separate developer CLI: Git retrieves source, the installer copies local source,
and the compiler resolves imports. `joenv run` and `joenv build` pass
`-I mojo_packages/packages`, so applications write `from typejo import ...`.
The supported `-I` flag and `mojo build` behavior were checked against the
installed Mojo 1.1.0 compiler.

## Layout trade-off

Dependencies live under `mojo_packages/packages/`, grouped under one project
local directory. This makes generated dependencies easy to identify and
removes repository metadata and unrelated files from installed packages. The
compiler receives the parent `packages/` directory as its import root. V0.1
does not isolate compiler versions or create a separate development runtime.

The CLI is native Mojo. A future release may distribute a compiled Joenv
binary when Mojo's process and filesystem APIs provide a stable, portable
distribution path; the project should not require Python as a bridge.
