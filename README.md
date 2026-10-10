# Joenv

Joenv is a small Git based dependency manager for Mojo projects. It installs
the importable Mojo package directory into `mojo_packages/packages/`, records
the Git commit in `joenv.lock`, and passes that directory to the Mojo compiler.

## Requirements

- Mojo 1.1.0 or newer on `PATH` (the `joenv` launcher runs the native Mojo CLI
  source in this repository).
- Git on `PATH` and network access to public GitHub repositories.

The package manager is written in Mojo. Its launcher is a short POSIX shell
script; Joenv does not add Python or any runtime dependency to consumer Mojo
applications.

## Quick start

```sh
mkdir demo && cd demo
joenv init
joenv add github.com/alanersia/typejo
joenv run src/main.mojo
```

`joenv init` creates `joenv.toml`, `joenv.lock`, `src/main.mojo`, and the
`mojo_packages/packages/` install directory. `joenv add` clones the repository,
pins its current commit, detects `typejo/__init__.mojo`, and installs only the
`typejo/` package. `joenv install` restores exact commits from the lockfile.

The `joenv` executable in this checkout can be used directly. To put it on
`PATH`, install this repository or add its root directory to `PATH`.

For a system-wide user command, compile and install the native Mojo CLI into
`~/.local/bin`:

```sh
sh install.sh
joenv --help
```

If `~/.local/bin` is not on `PATH`, add it to your shell configuration. To
choose another install directory, set `JOENV_INSTALL_DIR` when running the
installer.

## Commands

- `joenv init` — create a project manifest and starter source tree.
- `joenv add <github-url>` — install a public GitHub package at its current
  commit and update manifest and lockfile.
- `joenv install` — install dependencies at locked commits.
- `joenv run <source.mojo> [args...]` — run through Mojo with
  `-I mojo_packages/packages`.
- `joenv build <source.mojo>` — build with the same import search path.

See [architecture](docs/architecture.md), [manifest and lockfile](docs/manifest.md),
and [roadmap](docs/roadmap.md) for details and current limits.
