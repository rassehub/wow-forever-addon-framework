#!/usr/bin/env bash
# Builds Lua 5.1.5 (the language version the WoW client embeds) into .tools/lua.
# Needs: curl, tar, make, a C compiler. Nothing is installed system-wide.
set -euo pipefail

root="$(cd "$(dirname "$0")/.." && pwd)"
out="$root/.tools"
ver="lua-5.1.5"
sha="2640fc56a795f29d28ef15e13c34a47e223960b0240e8cb0a82d9b0738695333"

if [ -x "$out/lua" ]; then
	echo "already built: $out/lua"
	exit 0
fi

mkdir -p "$out/src"
cd "$out/src"
curl -fsSL -o "$ver.tar.gz" "https://www.lua.org/ftp/$ver.tar.gz"
echo "$sha  $ver.tar.gz" | sha256sum -c -
tar xzf "$ver.tar.gz"
# posix target: no readline dependency
make -C "$ver" posix MYCFLAGS=-w >/dev/null
cp "$ver/src/lua" "$out/lua"
"$out/lua" -v
