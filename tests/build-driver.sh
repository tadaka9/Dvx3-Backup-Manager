#!/usr/bin/env bash
# Behavioral checks for target parsing and fail-fast validation (no clean/build side effects).
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
"$ROOT/build.sh" --help >/dev/null
if "$ROOT/build.sh" clean invalid-command >/dev/null 2>&1; then echo 'Unknown command accepted' >&2; exit 1; fi
if "$ROOT/build.sh" clean --target=foreign-cpu >/dev/null 2>&1; then echo 'Foreign target accepted' >&2; exit 1; fi
if VALAC=missing-dvx3-valac "$ROOT/build.sh" core >/dev/null 2>&1; then echo 'Missing compiler accepted' >&2; exit 1; fi
if CC=false "$ROOT/build.sh" core >/dev/null 2>&1; then echo 'Failed compiler accepted' >&2; exit 1; fi
if CROSS_COMPILE=foreign- "$ROOT/build.sh" core >/dev/null 2>&1; then echo 'Cross compiler accepted' >&2; exit 1; fi
if JOBS=0 "$ROOT/build.sh" core >/dev/null 2>&1; then echo 'Invalid parallel count accepted' >&2; exit 1; fi
printf 'Build driver behavior verified.\n'
