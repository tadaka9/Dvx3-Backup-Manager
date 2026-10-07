#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BIN="$ROOT/build/gui/dvx3-backup-manager"
if [[ ! -x "$BIN" ]]; then
  "$ROOT/build.sh" gui
fi
exec "$BIN" "$@"
