#!/bin/bash
# build_cli_fixed.sh - Fixed Dvx3 CLI build script

set -e

echo "Building Dvx3 Backup Manager CLI..."

UNAME_OUT="$(uname -s 2>/dev/null || echo unknown)"
case "$UNAME_OUT" in
    MINGW*|MSYS*|CYGWIN*)
        GIO_PKG="gio-2.0"
        VALA_DEFINES=""
        ;;
    *)
        GIO_PKG="gio-2.0 --pkg gio-unix-2.0"
        VALA_DEFINES="-D POSIX"
        ;;
esac

echo "[1/3] Generating C sources from Vala..."
valac --pkg glib-2.0 --pkg $GIO_PKG --pkg json-glib-1.0 \
    --vapidir=vala-extra-vapis --pkg libsodium \
    $VALA_DEFINES \
    libdvx3.vala -C -d build/cli-gen-c

echo "[2/3] Compiling library object..."
mkdir -p build/cli-build
gcc -c -fPIC -O2 \
    -I/usr/include/glib-2.0 \
    -I/usr/lib/x86_64-linux-gnu/glib-2.0/include \
    -I/usr/include/json-glib-1.0 \
    "build/cli-gen-c/libdvx3.c" -o "build/cli-build/libdvx3.o"

echo "[3/3] Compiling CLI with library..."
# Compile main.vala into C first
valac --pkg glib-2.0 --pkg $GIO_PKG --pkg json-glib-1.0 \
    --vapidir=vala-extra-vapis --pkg libsodium \
    $VALA_DEFINES \
    main.vala -C -d build/cli-main

# Compile the generated C
gcc -c -O2 \
    -I/usr/include/glib-2.0 \
    -I/usr/lib/x86_64-linux-gnu/glib-2.0/include \
    -I/usr/include/json-glib-1.0 \
    $(if [ "$UNAME_OUT" = "Linux" ]; then echo '-I/usr/include/gio-unix-2.0'; else echo ''; fi) \
    "build/cli-main/main.c" -o "build/cli-build/main.o"

# Compile dvx3-cli.vala with includedir for libdvx3 header
valac --pkg glib-2.0 --pkg $GIO_PKG --pkg json-glib-1.0 \
    --vapidir=vala-extra-vapis --pkg libsodium \
    $VALA_DEFINES \
    --includedir="build/cli-gen-c" \
    -o build/cli-build/dvx3-cli.o \
    dvx3-cli.vala

# Link everything together
gcc -o dvx3-backup \
    build/cli-main/main.o \
    build/cli-build/dvx3-cli.o \
    build/cli-build/libdvx3.o \
    -lglib-2.0 \
    $(if [ "$UNAME_OUT" = "Linux" ]; then echo '-lgio-2.0 -lgio-unix-2.0'; else echo ''; fi) \
    -ljson-glib-1.0 \
    -lsodium \
    '-Wl,-rpath,$ORIGIN'

echo ""
echo "✓ Build complete!"
echo "  Binary: ./dvx3-backup"
echo ""
echo "Test it:"
echo "  ./dvx3-backup --help"
