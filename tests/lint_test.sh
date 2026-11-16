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
[ $fail = 0 ] && echo "lint_test: ok"
exit $fail
