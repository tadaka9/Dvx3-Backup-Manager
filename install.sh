#!/usr/bin/env bash
# POSIX development installation; no release packaging is implied.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PREFIX="${PREFIX:-/usr/local}"
[[ $PREFIX == /* && $PREFIX != / ]] || { echo 'PREFIX must be an absolute directory other than /' >&2; exit 1; }
case "$(uname -s)" in Linux|Darwin) ;; *) echo 'Use build/bin directly in MSYS2; this installer is POSIX-only' >&2; exit 1 ;; esac
"$ROOT/build.sh" cli manager
mkdir -p "$PREFIX/bin" "$PREFIX/lib" "$PREFIX/include" "$PREFIX/share/dvx3"
install -m 755 "$ROOT/build/bin/dvx3" "$ROOT/build/bin/backup-manager" "$PREFIX/bin/"
install -m 644 "$ROOT/build/lib/libdvx3.a" "$PREFIX/lib/"
install -m 644 "$ROOT/build/generated/dvx3.h" "$ROOT/dvx3.hpp" "$PREFIX/include/"
install -m 644 "$ROOT/BUILD.md" "$ROOT/ARCHITECTURE.md" "$ROOT/BACKUP_MANAGER_GUIDE.md" "$PREFIX/share/dvx3/"
printf 'Installed core, CLI and manager in %s; dependencies must remain installed.\n' "$PREFIX"
