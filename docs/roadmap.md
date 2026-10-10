# Roadmap

## v0.1 (current)

- Public GitHub HTTPS dependencies.
- Git commit pinning and locked reinstall.
- Conventional Mojo package detection and project-local installation.
- `init`, `add`, `install`, `run`, and `build` commands.
- Basic URL, package-name, path, and symlink safety checks.

## Later

- Broader TOML support and clearer diagnostics for manifest editing.
- Dependency graph and transitive dependency resolution.
- Tags, branches, and semantic versions with lockfile pinning.
- Source cache to avoid repeated repository clones.
- Compiled Joenv distributions and isolated developer toolchains.
- Additional Git hosts and authenticated/private sources.

Joenv does not provide a package registry, publishing, PyPI compatibility,
Python virtual environments, compiler installation, or cloud deployment.
