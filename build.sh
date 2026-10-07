#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BUILD="$ROOT/build"
MODE="${1:-all}"
VAPIDIR="$ROOT/vala-extra-vapis"

need() { command -v "$1" >/dev/null 2>&1 || { echo "error: missing dependency: $1" >&2; exit 1; }; }
need pkg-config
need valac

case "$(uname -s)" in
  Linux*)  GIO_PKG=gio-unix-2.0; VALA_DEFINES=(-D POSIX); LIB_EXT=so ;;
  Darwin*) GIO_PKG=gio-2.0;      VALA_DEFINES=(-D POSIX); LIB_EXT=dylib ;;
  MINGW*|MSYS*|CYGWIN*) GIO_PKG=gio-2.0; VALA_DEFINES=(); LIB_EXT=dll ;;
  *) echo "error: unsupported platform: $(uname -s)" >&2; exit 1 ;;
esac

for pkg in glib-2.0 gio-2.0 json-glib-1.0 libsodium "$GIO_PKG"; do
  pkg-config --exists "$pkg" || { echo "error: pkg-config dependency not found: $pkg" >&2; exit 1; }
done

mkdir -p "$BUILD/bin" "$BUILD/lib" "$BUILD/generated"

build_core() {
  echo "[core] libdvx3 + dvx3 CLI"
  local lib="$BUILD/lib/libdvx3.$LIB_EXT"
  local shared_flags=()
  case "$LIB_EXT" in
    so)    shared_flags=(-X -fPIC -X -shared) ;;
    dylib) shared_flags=(-X -fPIC -X -dynamiclib) ;;
    dll)   shared_flags=(-X -shared -X -Wl,--export-all-symbols) ;;
  esac

  valac --vapidir="$VAPIDIR" \
    --pkg glib-2.0 --pkg gio-2.0 --pkg "$GIO_PKG" \
    --pkg json-glib-1.0 --pkg libsodium \
    "${VALA_DEFINES[@]}" "${shared_flags[@]}" \
    --library=dvx3 --vapi="$BUILD/generated/dvx3.vapi" \
    --header="$BUILD/generated/dvx3.h" \
    -o "$lib" "$ROOT/libdvx3.vala"

  local rpath=()
  case "$LIB_EXT" in
    so) rpath=(-X '-Wl,-rpath,$ORIGIN/../lib') ;;
    dylib) rpath=(-X '-Wl,-rpath,@loader_path/../lib') ;;
  esac

  valac --vapidir="$VAPIDIR" --vapidir="$BUILD/generated" \
    --pkg glib-2.0 --pkg gio-2.0 --pkg "$GIO_PKG" \
    --pkg json-glib-1.0 --pkg libsodium --pkg dvx3 \
    "${VALA_DEFINES[@]}" \
    -X "-I$BUILD/generated" -X "-L$BUILD/lib" -X -ldvx3 \
    "${rpath[@]}" \
    -o "$BUILD/bin/dvx3" "$ROOT/dvx3-cli.vala"
}

build_manager() {
  build_core
  need g++
  echo "[manager] C++ backup manager"
  g++ -std=c++17 -O2 -I"$ROOT" -I"$BUILD/generated" \
    "$ROOT/backup-manager.cpp" -L"$BUILD/lib" -ldvx3 \
    $(pkg-config --cflags --libs glib-2.0 gio-2.0 "$GIO_PKG" json-glib-1.0 libsodium) \
    -Wl,-rpath,'$ORIGIN/../lib' -o "$BUILD/bin/backup-manager"
}

build_gui() {
  need cmake
  echo "[gui] Qt6 desktop"
  cmake -S "$ROOT/gui/qt/qtdesktop" -B "$BUILD/gui" -DCMAKE_BUILD_TYPE=Release
  cmake --build "$BUILD/gui" --parallel
}

case "$MODE" in
  core) build_core ;;
  manager) build_manager ;;
  gui) build_gui ;;
  all) build_manager; build_gui ;;
  clean) rm -rf "$BUILD" ;;
  *) echo "usage: $0 {core|manager|gui|all|clean}" >&2; exit 2 ;;
esac
