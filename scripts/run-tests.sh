#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
"$ROOT/build.sh" manager
mkdir -p "$ROOT/build/tests"
CXX="${CXX:-g++}"
COMMON=(-std=c++17 -O2 -I"$ROOT" -I"$ROOT/build/generated")
LDFLAGS=(-L"$ROOT/build/lib" -Wl,-rpath,'$ORIGIN/../lib' -ldvx3)
PKG=( $(pkg-config --cflags --libs glib-2.0 gio-2.0 gio-unix-2.0 json-glib-1.0 libsodium) )
for src in test-simple-backup.cpp test-exclusion.cpp; do
  out="$ROOT/build/tests/${src%.cpp}"
  "$CXX" "${COMMON[@]}" "$ROOT/$src" "${PKG[@]}" "${LDFLAGS[@]}" -o "$out"
  "$out"
done
