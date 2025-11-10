#!/bin/bash
# Build script for dvx3 library and CLI

set -e

VAPIDIR="vala-extra-vapis"
PACKAGES="--pkg glib-2.0 --pkg gio-unix-2.0 --pkg json-glib-1.0 --pkg posix --pkg libsodium"

echo "Building libdvx3..."

# Build shared library
valac --vapidir=$VAPIDIR $PACKAGES \
    --library=dvx3 \
    --vapi=dvx3.vapi \
    --header=dvx3.h \
    -X -fPIC \
    -X -shared \
    -o libdvx3.so \
    libdvx3.vala

echo "Building dvx3 CLI..."

# Build CLI executable
valac --vapidir=$VAPIDIR $PACKAGES \
    --pkg dvx3 \
    --vapidir=. \
    -X -I. \
    -X -L. \
    -X -ldvx3 \
    -X -Wl,-rpath='$ORIGIN' \
    -o dvx3 \
    dvx3-cli.vala

echo "✅ Build complete!"
echo ""
echo "Files created:"
echo "  - libdvx3.so    (shared library)"
echo "  - dvx3.vapi     (Vala API)"
echo "  - dvx3.h        (C header)"
echo "  - dvx3          (CLI executable)"
echo ""
echo "Usage:"
echo "  ./dvx3 encrypt <folder> -p <password> -o <output.dvx3>"
echo "  ./dvx3 decrypt <archive.dvx3> -p <password> -o <output_dir>"
