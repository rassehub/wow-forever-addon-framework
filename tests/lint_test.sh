#!/usr/bin/env bash
# fk lint must flag every planted problem in tests/fixtures/BadAddon and pass a clean addon.
cd "$(dirname "$0")/.."
out="$(tools/fk lint tests/fixtures/BadAddon)" && { echo "FAIL: lint passed BadAddon"; exit 1; }
fail=0
for code in toc-interface toc-field savedvariable-undeclared ui-enum-should-be-slider \
	deprecated-api secret-compute blizzard-template hardcoded-font global-function global-leak; do
	grep -q "\[$code\]" <<<"$out" || { echo "FAIL: lint did not report $code"; fail=1; }
done
tools/fk lint tests/fixtures/Plain >/dev/null || { echo "FAIL: lint rejected the clean Plain addon"; tools/fk lint tests/fixtures/Plain; fail=1; }
tools/fk lint tests/fixtures/Plain | grep -q "global-function" && { echo "FAIL: lint flagged a forward-declared local function"; fail=1; }
# Bindings.xml: written from FK.Binding calls, stale or hand-written ones reported
tmp="$(mktemp -d)"; trap 'rm -rf "$tmp"' EXIT
cp -r tests/fixtures/Plain "$tmp/Plain"
printf '<Bindings><Binding name="X">print(1)</Binding></Bindings>\n' > "$tmp/Plain/Bindings.xml"
tools/fk lint "$tmp/Plain" | grep -q "bindings-handwritten" || { echo "FAIL: a hand-written Bindings.xml was not reported"; fail=1; }
rm "$tmp/Plain/Bindings.xml"
printf '\nns.FK = ns.FK or { Binding = function() end }\nns.FK.Binding("PLAIN_TOGGLE", "Toggle Plain", function() end)\n-- FK.Binding("PLAIN_COMMENTED", "no", f)\n' >> "$tmp/Plain/Plain.lua"
tools/fk lint "$tmp/Plain" | grep -q "bindings-stale" || { echo "FAIL: a missing Bindings.xml was not reported"; fail=1; }
tools/fk sync "$tmp/Plain" >/dev/null
grep -q 'name="PLAIN_TOGGLE"' "$tmp/Plain/Bindings.xml" && ! grep -q PLAIN_COMMENTED "$tmp/Plain/Bindings.xml" || { echo "FAIL: sync did not write the right Bindings.xml"; fail=1; }
tools/fk lint "$tmp/Plain" | grep -q "bindings-" && { echo "FAIL: lint still reports bindings after sync"; fail=1; }
[ $fail = 0 ] && echo "lint_test: ok"
exit $fail
