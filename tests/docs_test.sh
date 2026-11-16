#!/bin/sh
# The component catalog matches the code.
cd "$(dirname "$0")/.." && tools/fk docs --check >/dev/null && echo "docs_test: ok"
