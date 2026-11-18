#!/bin/sh
# fk header: adds the FK line once, reuses an existing namespace line, skips Libs/, keeps CRLF.
set -e
cd "$(dirname "$0")/.."
d=$(mktemp -d); trap 'rm -rf "$d"' EXIT
mkdir -p "$d/A/Modules/UI" "$d/A/Libs/X"
printf 'print(1)\n' > "$d/A/Plain.lua"
printf -- '-- c\nlocal name, addon = ...\nprint(addon)\n' > "$d/A/Modules/UI/Named.lua"
printf 'local A = select(2, ...)\r\nprint(A)\r\n' > "$d/A/Modules/Crlf.lua"
printf 'print(2)\n' > "$d/A/Libs/X/Lib.lua"
tools/fk header "$d/A" >/dev/null
tools/fk header "$d/A" | grep -q "^0 file" # second run changes nothing
[ "$(head -2 "$d/A/Plain.lua")" = "$(printf 'local _, ns = ...\nlocal FK = ns.FK')" ]
[ "$(sed -n 3p "$d/A/Modules/UI/Named.lua")" = "local FK = addon.FK" ]
[ "$(sed -n 2p "$d/A/Modules/Crlf.lua")" = "$(printf 'local FK = A.FK\r')" ]
[ "$(cat "$d/A/Libs/X/Lib.lua")" = "print(2)" ]
echo "header_test: ok"
