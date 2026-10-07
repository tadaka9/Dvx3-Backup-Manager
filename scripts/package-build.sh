#!/usr/bin/env bash
# Archive tested native outputs; runtime dependencies are not bundled.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"
case "$(uname -s)" in
  Linux) os=linux; library=libdvx3.so; exe='' ;;
  Darwin) os=macos; library=libdvx3.dylib; exe='' ;;
  MINGW*|MSYS*) os=windows; library=libdvx3.dll; exe=.exe
    [[ ${MSYSTEM:-} == UCRT64 ]] || { echo 'Use MSYS2 UCRT64' >&2; exit 1; } ;;
  *) echo 'Unsupported packaging OS' >&2; exit 1 ;;
esac
case "$(uname -m)" in
  x86_64|amd64) arch=x86_64 ;;
  aarch64|arm64) arch=arm64 ;;
  *) echo 'No verified release target for this architecture' >&2; exit 1 ;;
esac
name="dvx3-$os-$arch"
stage="$ROOT/build/package/$name"
artifacts="$ROOT/build/artifacts"
# Check all inputs before replacing a previous staging tree/archive.
for file in "build/bin/dvx3$exe" "build/bin/backup-manager$exe"   "build/bin/dvx3-backup-manager$exe" "build/lib/$library" build/lib/libdvx3.a   build/generated/dvx3.h build/generated/dvx3.vapi; do
  [[ -s $file ]] || { printf 'Missing build output: %s (run ./build.sh all test first)\n' "$file" >&2; exit 1; }
done
rm -rf "$stage"
mkdir -p "$stage/bin" "$stage/lib" "$stage/include" "$stage/share/dvx3" "$artifacts"
cp "build/bin/dvx3$exe" "build/bin/backup-manager$exe"   "build/bin/dvx3-backup-manager$exe" "$stage/bin/"
cp "build/lib/$library" build/lib/libdvx3.a "$stage/lib/"
if [[ $os == windows ]]; then
  cp "build/lib/$library" "$stage/bin/"
  cp build/lib/libdvx3.dll.a "$stage/lib/"
fi
cp build/generated/dvx3.h dvx3.hpp "$stage/include/"
cp build/generated/dvx3.vapi config/codecs.example.ini "$stage/share/dvx3/"
cp LICENSE BUILD.md ARCHITECTURE.md COMPRESSION.md BACKUP_MANAGER_GUIDE.md GUI_GUIDE.md "$stage/"
{
  printf 'Platform: %s-%s\n' "$os" "$arch"
  printf 'Commit: %s\n' "$(git rev-parse HEAD)"
  printf 'Runtime GLib/GIO, JSON-GLib and libsodium versions:\n'
  pkg-config --modversion glib-2.0 gio-2.0 json-glib-1.0 libsodium
} > "$stage/BUILD-INFO.txt"
cat > "$stage/README.txt" <<'EOF'
Native Dvx3 build bundle: CLI, Vala manager, Qt GUI and core bindings.
Extract this archive, then run the executables in bin/.
Install the runtime libraries and archive/codec tools listed in BUILD.md first.
On Windows use MSYS2 UCRT64 with its runtime directories on PATH.
On macOS use the corresponding Homebrew architecture and dependency prefixes.
This archive does not bundle system libraries, Qt plugins or codec executables.
See BUILD-INFO.txt for the source commit and build dependency versions.
EOF
archive="$artifacts/$name.tar.gz"
tar -czf "$archive" -C "$ROOT/build/package" "$name"
if command -v sha256sum >/dev/null 2>&1; then
  digest="$(sha256sum "$archive")"
else
  digest="$(shasum -a 256 "$archive")"
fi
printf '%s  %s\n' "${digest%% *}" "$name.tar.gz" > "$archive.sha256"
printf 'Created %s and SHA256 checksum\n' "$archive"
