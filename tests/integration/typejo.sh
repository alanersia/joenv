#!/bin/sh
set -eu

repo=$(CDPATH= cd -- "$(dirname -- "$0")/../.." && pwd)
project=$(mktemp -d)
trap 'rm -rf "$project"' EXIT
mkdir -p "$project/src"
cp "$repo/examples/typejo-consumer/src/main.mojo" "$project/src/main.mojo"
cd "$project"
"$repo/joenv" init
"$repo/joenv" add github.com/alanersia/typejo
test -f mojo_packages/packages/typejo/__init__.mojo
test ! -f mojo_packages/packages/typejo/README.md
grep -Eq 'commit = "[0-9a-f]{40,64}"' joenv.lock
test "$(grep -c '^typejo = ' joenv.toml)" -eq 1
"$repo/joenv" add https://github.com/alanersia/typejo.git
test "$(grep -c '^typejo = ' joenv.toml)" -eq 1
before=$(cksum mojo_packages/packages/typejo/__init__.mojo)
"$repo/joenv" install
after=$(cksum mojo_packages/packages/typejo/__init__.mojo)
test "$before" = "$after"
"$repo/joenv" run src/main.mojo
"$repo/joenv" build src/main.mojo
test -x main
if output=$(GIT_CONFIG_COUNT=1 GIT_CONFIG_KEY_0="url.file://$project/missing/.insteadOf" GIT_CONFIG_VALUE_0="https://github.com/alanersia/" "$repo/joenv" add github.com/alanersia/missing 2>&1); then
    echo "expected Joenv to reject a missing repository" >&2
    exit 1
fi
printf '%s\n' "$output" | grep -q 'Git clone failed; check the URL and network access'
