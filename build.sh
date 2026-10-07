#!/usr/bin/env bash
# Native build entry point. Bash 3.2+ (including macOS) and MSYS2 UCRT64.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$ROOT"
fail() { printf 'Build error: %s\n' "$*" >&2; exit 1; }
need() { command -v "$1" >/dev/null 2>&1 || fail "Required tool missing: $1"; }
usage() { echo 'Usage: ./build.sh [core|cli|manager|gui|all|clean|test ...] [--target=native|<os>-<arch>]'; }
case "$(uname -s)" in
  Linux) OS=linux ;;
  Darwin) OS=macos ;;
  MINGW*|MSYS*) OS=windows; [[ ${MSYSTEM:-} == UCRT64 ]] || fail 'Use the MSYS2 UCRT64 shell on Windows' ;;
  *) fail "Unsupported OS: $(uname -s)" ;;
esac
case "$(uname -m)" in
  x86_64|amd64) ARCH=x86_64 ;;
  aarch64|arm64) ARCH=arm64 ;;
  armv7l|armv6l) ARCH=armhf ;;
  i?86) ARCH=x86 ;;
  *) fail "Unsupported architecture: $(uname -m)" ;;
esac
NATIVE="$OS-$ARCH"
TARGET="${TARGET:-native}"
COMMANDS=()
for arg in "$@"; do
  case "$arg" in
    --target=*) TARGET="${arg#*=}" ;;
    -h|--help) usage; exit 0 ;;
    core|cli|manager|gui|all|clean|test) COMMANDS+=("$arg") ;;
    *) usage >&2; fail "Unknown argument: $arg" ;;
  esac
done
[[ $TARGET == native || $TARGET == "$NATIVE" ]] || fail "Target $TARGET differs from native $NATIVE; cross-compilation is not supported"
[[ -z ${CROSS_COMPILE:-} && -z ${CROSS_COMPILE_TARGET:-} ]] || fail 'Cross-compilation requires a target sysroot and is not supported'
[[ ${#COMMANDS[@]} -gt 0 ]] || COMMANDS=(all)
BUILD="$ROOT/build"
VALAC="${VALAC:-valac}"
CC="${CC:-cc}"
CXX="${CXX:-c++}"
PKG_CONFIG="${PKG_CONFIG:-pkg-config}"
export CC CXX PKG_CONFIG
JOBS="${JOBS:-2}"
[[ $JOBS =~ ^[1-9][0-9]*$ ]] || fail 'JOBS must be a positive integer'
EXE=''; LIB='libdvx3.so'
case "$OS" in macos) LIB=libdvx3.dylib ;; windows) EXE=.exe; LIB=libdvx3.dll ;; esac
CORE_READY=0
CLI_READY=0
MANAGER_READY=0
validate_core() {
  need "$VALAC"; need "$CC"; need "$PKG_CONFIG"; need ar
  local vala_api vala_version compiler
  vala_api="$("$VALAC" --api-version)"
  [[ $vala_api =~ ^([0-9]+)\.([0-9]+)$ ]] || fail "Invalid Vala API version: $vala_api"
  (( 10#${BASH_REMATCH[1]} > 0 || 10#${BASH_REMATCH[2]} >= 56 )) || fail 'Vala 0.56+ is required'
  vala_version="$("$VALAC" --version)"
  compiler="$("$CC" -dumpmachine)"
  "$PKG_CONFIG" --print-errors --exists 'glib-2.0 >= 2.66' gio-2.0 json-glib-1.0 libsodium
  mkdir -p "$BUILD/bin" "$BUILD/lib" "$BUILD/generated" "$BUILD/obj" "$BUILD/tests"
  printf 'Native %s; %s; %s\n' "$NATIVE" "$vala_version" "$compiler"
  # The compiler must produce a runnable native binary (catches foreign CC/sysroots).
  printf 'int main(void) { return 0; }\n' > "$BUILD/obj/native-check.c"
  "$CC" "$BUILD/obj/native-check.c" -o "$BUILD/obj/native-check$EXE"
  "$BUILD/obj/native-check$EXE" || fail 'C compiler cannot produce runnable native executables'
}
build_core() {
  [[ $CORE_READY == 0 ]] || return 0
  validate_core
  "$VALAC" -C --directory "$BUILD/generated" --basedir "$ROOT/vala" \
    --library dvx3 --header "$BUILD/generated/dvx3.h" --vapi "$BUILD/generated/dvx3.vapi" \
    --vapidir "$ROOT/vala/bindings" --pkg libsodium --pkg gio-2.0 --pkg json-glib-1.0 \
    vala/core/dvx3.vala vala/manager/manager.vala
  local pkg_flags pkg_output objects=() src obj
  pkg_output="$("$PKG_CONFIG" --cflags glib-2.0 gio-2.0 json-glib-1.0 libsodium)"
  read -r -a pkg_flags <<< "$pkg_output"
  for src in "$BUILD/generated/core/dvx3.c" "$BUILD/generated/manager/manager.c"; do
    obj="$BUILD/obj/$(basename "${src%.c}").o"
    "$CC" -O2 -fPIC -I"$BUILD/generated" "${pkg_flags[@]}" -c "$src" -o "$obj"
    objects+=("$obj")
  done
  ar rcs "$BUILD/lib/libdvx3.a" "${objects[@]}"
  pkg_output="$("$PKG_CONFIG" --libs glib-2.0 gio-2.0 json-glib-1.0 libsodium)"
  read -r -a pkg_flags <<< "$pkg_output"
  case "$OS" in
    macos) "$CC" -dynamiclib -Wl,-install_name,@rpath/libdvx3.dylib "${objects[@]}" "${pkg_flags[@]}" -o "$BUILD/lib/$LIB" ;;
    windows) "$CC" -shared "${objects[@]}" "${pkg_flags[@]}" -Wl,--out-implib,"$BUILD/lib/libdvx3.dll.a" -o "$BUILD/lib/$LIB"
      cp "$BUILD/lib/$LIB" "$BUILD/bin/$LIB" ;;
    linux) "$CC" -shared -Wl,-z,defs "${objects[@]}" "${pkg_flags[@]}" -o "$BUILD/lib/$LIB" ;;
  esac
  CORE_READY=1
}
vala_app() {
  local flags pkg_output link_args=() flag
  pkg_output="$("$PKG_CONFIG" --libs glib-2.0 gio-2.0 json-glib-1.0 libsodium)"
  read -r -a flags <<< "$pkg_output"
  for flag in "${flags[@]}"; do link_args+=(-X "$flag"); done
  "$VALAC" --cc "$CC" --directory "$BUILD/generated" \
    --vapidir "$BUILD/generated" --pkg dvx3 --pkg gio-2.0 --pkg json-glib-1.0 \
    -X -I"$BUILD/generated" -X "$BUILD/lib/libdvx3.a" "${link_args[@]}" \
    "$1" -o "$2"
}
build_cli() {
  [[ $CLI_READY == 0 ]] || return 0
  build_core
  vala_app vala/cli/app.vala "$BUILD/bin/dvx3$EXE"
  CLI_READY=1
}
build_manager() {
  [[ $MANAGER_READY == 0 ]] || return 0
  build_core
  vala_app vala/manager/app.vala "$BUILD/bin/backup-manager$EXE"
  MANAGER_READY=1
}
build_gui() {
  build_core; need cmake; need "$CXX"
  cmake -S gui/qt/qtdesktop -B "$BUILD/gui" \
    -DCMAKE_BUILD_TYPE=Release -DCMAKE_CXX_COMPILER="$CXX" -DDVX3_BUILD_DIR="$BUILD"
  cmake --build "$BUILD/gui" --config Release --parallel "$JOBS"
}
run_tests() {
  build_cli; build_manager
  need "$CXX"; need tar; need zstd; need gzip; need xz
  vala_app tests/core.vala "$BUILD/tests/core-test$EXE"
  "$BUILD/tests/core-test$EXE"
  local flags pkg_output
  pkg_output="$("$PKG_CONFIG" --cflags --libs glib-2.0 gio-2.0 json-glib-1.0 libsodium)"
  read -r -a flags <<< "$pkg_output"
  "$CXX" -std=c++17 -I"$ROOT" -I"$BUILD/generated" tests/binding.cpp \
    "$BUILD/lib/libdvx3.a" "${flags[@]}" -o "$BUILD/tests/binding-test$EXE"
  "$BUILD/tests/binding-test$EXE"
  "$BUILD/bin/dvx3$EXE" --version
  "$BUILD/bin/backup-manager$EXE" --version
  "$BUILD/bin/backup-manager$EXE" --help
  "$ROOT/tests/build-driver.sh"
}
for cmd in "${COMMANDS[@]}"; do
  case "$cmd" in
    clean) rm -rf "$BUILD"; CORE_READY=0; CLI_READY=0; MANAGER_READY=0 ;;
    core) build_core ;;
    cli) build_cli ;;
    manager) build_manager ;;
    gui) build_gui ;;
    all) build_cli; build_manager; build_gui ;;
    test) run_tests ;;
  esac
done
