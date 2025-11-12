#!/bin/bash
# Generate plain C sources from Vala (no compilation)
set -e

VAPIDIR="vala-extra-vapis"
PACKAGES="--pkg glib-2.0 --pkg gio-unix-2.0 --pkg json-glib-1.0 --pkg posix --pkg libsodium"
OUTDIR="gen-c"

rm -rf "$OUTDIR"
mkdir -p "$OUTDIR"

echo "Generating C for libdvx3..."
valac --vapidir="$VAPIDIR" $PACKAGES \
  --ccode \
  --directory="$OUTDIR" \
  --library=dvx3 \
  --vapi=dvx3.vapi \
  --header=dvx3.h \
  libdvx3.vala

# Also generate C code for the CLI (optional)
echo "Generating C for dvx3 CLI..."
valac --vapidir="$VAPIDIR" $PACKAGES \
  --ccode \
  --directory="$OUTDIR" \
  --pkg dvx3 \
  --vapidir=. \
  dvx3-cli.vala

echo "✅ C sources generated in $OUTDIR/"
