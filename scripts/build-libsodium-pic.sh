#!/bin/bash
# scripts/build-libsodium-pic.sh
# Helper script to build and install a PIC-enabled static libsodium into /usr/local.
# Usage: ./scripts/build-libsodium-pic.sh [--version <version>] [--prefix <prefix>]
set -euo pipefail

VERSION="1.0.20"
PREFIX="/usr/local"

while [[ $# -gt 0 ]]; do
    case $1 in
        --version)
            VERSION="$2"; shift 2;;
        --prefix)
            PREFIX="$2"; shift 2;;
        --help|-h)
            echo "Usage: $0 [--version <version>] [--prefix <prefix>]"; exit 0;;
        *)
            echo "Unknown option: $1"; exit 1;;
    esac
done

echo "Building libsodium v$VERSION with PIC, installing to $PREFIX"

TMPDIR=$(mktemp -d)
trap 'rm -rf "$TMPDIR"' EXIT

wget -qO "$TMPDIR/libsodium.tar.gz" "https://download.libsodium.org/libsodium/releases/libsodium-$VERSION.tar.gz"
mkdir -p "$TMPDIR/src"
tar -xzf "$TMPDIR/libsodium.tar.gz" -C "$TMPDIR/src"

pushd "$TMPDIR/src/libsodium-$VERSION"
# Build with -fPIC to create a static libsodium usable by shared libraries
CFLAGS="-fPIC" CXXFLAGS="-fPIC" ./configure --prefix="$PREFIX" --enable-static --disable-shared
make -j$(nproc)
if command -v sudo >/dev/null 2>&1; then
    sudo make install
else
    echo "sudo not found; attempting to install as current user (may fail)"
    make install
fi
# Update pkg-config path if /usr/local
if [ "$PREFIX" = "/usr/local" ]; then
    if [ -w /etc/ld.so.conf.d ]; then
        echo "/usr/local/lib" | sudo tee /etc/ld.so.conf.d/local-lib.conf >/dev/null || true
    fi
    if command -v sudo >/dev/null 2>&1; then
        sudo ldconfig || true
    else
        ldconfig || true
    fi
fi
popd

echo "Installed libsodium into $PREFIX. If you want to use the new libsodium with pkg-config, ensure PKG_CONFIG_PATH includes $PREFIX/lib/pkgconfig"

exit 0
