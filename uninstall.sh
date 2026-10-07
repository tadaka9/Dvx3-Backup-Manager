#!/usr/bin/env bash
set -euo pipefail
PREFIX="${PREFIX:-/usr/local}"
[[ $PREFIX == /* && $PREFIX != / ]] || { echo 'PREFIX must be an absolute directory other than /' >&2; exit 1; }
rm -f "$PREFIX/bin/dvx3" "$PREFIX/bin/backup-manager" "$PREFIX/lib/libdvx3.a" \
  "$PREFIX/include/dvx3.h" "$PREFIX/include/dvx3.hpp" \
  "$PREFIX/share/dvx3/BUILD.md" "$PREFIX/share/dvx3/ARCHITECTURE.md" "$PREFIX/share/dvx3/BACKUP_MANAGER_GUIDE.md"
printf 'Removed the development installation from %s. User configuration is preserved.\n' "$PREFIX"
