#!/bin/sh
set -eu

repo=$(CDPATH= cd -P -- "$(dirname -- "$0")" && pwd)
install_dir=${JOENV_INSTALL_DIR:-"$HOME/.local/bin"}
mkdir -p "$install_dir"
tmp="$install_dir/.joenv.$$"
trap 'rm -f "$tmp"' EXIT HUP INT TERM

mojo build -I "$repo" "$repo/src/main.mojo" -o "$tmp"
chmod 755 "$tmp"
mv -f "$tmp" "$install_dir/joenv"
printf 'Installed joenv to %s/joenv\n' "$install_dir"
