#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BIN="$ROOT/build/bin/dvx3-backup-manager"
case "$(uname -s)" in MINGW*|MSYS*) BIN+=.exe ;; esac
if [[ ! -x "$BIN" ]]; then "$ROOT/build.sh" gui; fi
exec "$BIN" "$@"
