#!/bin/bash
# build_gui.sh - Build the Qt6 GUI for Backup Manager

set -e

echo "Building Backup Manager GUI..."

# Check for Qt6
if ! pkg-config --exists Qt6Widgets; then
    echo "Error: Qt6 not found. Install with:"
    echo "  Arch Linux: sudo pacman -S qt6-base"
    echo "  Debian/Ubuntu: sudo apt-get install qt6-base-dev"
    exit 1
fi

# 1. Generate C sources from Vala library
echo "[1/5] Generating C sources from Vala..."
if [ ! -d "gen-c" ]; then
    ./gen_c_sources.sh
fi

# 2. Compile generated C code
echo "[2/5] Compiling C library..."
gcc -c gen-c/libdvx3.c -o libdvx3.o \
    $(pkg-config --cflags glib-2.0 gio-unix-2.0 json-glib-1.0 libsodium) \
    -I.

# 3. Compile backup-manager implementation
echo "[3/5] Compiling backup manager library..."
g++ -c -fPIC backup-manager.hpp -o backup-manager-lib.o \
    -std=c++17 \
    $(pkg-config --cflags glib-2.0 gio-unix-2.0 json-glib-1.0 libsodium) \
    -I.

# 4. Run MOC on GUI header
echo "[4/5] Running Qt MOC..."
/usr/lib/qt6/moc backup-manager-gui.hpp -o backup-manager-gui.moc.cpp

# 5. Compile and link GUI
echo "[5/5] Compiling Qt6 GUI..."
g++ backup-manager-gui.cpp backup-manager-gui.moc.cpp libdvx3.o \
    -o backup-manager-gui \
    -std=c++17 -fPIC \
    $(pkg-config --cflags --libs Qt6Widgets glib-2.0 gio-unix-2.0 json-glib-1.0 libsodium) \
    -lstdc++fs \
    -I.

echo ""
echo "✓ Build complete!"
echo ""
echo "Run with: ./backup-manager-gui"
echo ""
