# Manifest and lockfile

`joenv.toml` is intentionally a small supported subset of TOML in v0.1:

```toml
[package]
name = "my-app"
version = "0.1.0"

[dependencies]
typejo = { git = "https://github.com/alanersia/typejo.git" }
```

Dependencies are keyed by Mojo import package name. Only public GitHub HTTPS
repository URLs are supported, including the shorthand
`github.com/owner/repository`. Joenv canonicalizes both forms to
`https://github.com/owner/repository.git`. Unsupported fields and dependency
sources fail explicitly.

`joenv.lock` records format version 1 and, for every import package, its
canonical Git URL, exact commit SHA, and package subdirectory. The subdirectory
is repository relative (`typejo` for Typejo). No package version is inferred
from a Git repository. Commit identity is the reproducibility mechanism.

`joenv add` resolves the current repository HEAD and updates the manifest and
lockfile. `joenv install` uses only commits recorded in the lockfile. Commit
checkouts are verified, and the package identity and subdirectory must still
match what the lockfile records.

The parser supports only the exact package and dependency declarations above;
quoted-string escapes, branch/tag selectors, registry dependencies, and
transitive dependencies are outside v0.1.
