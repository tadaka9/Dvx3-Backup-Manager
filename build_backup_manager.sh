#!/bin/bash
# build_backup_manager.sh - Build the backup manager application

set -e

echo "Building Backup Manager..."

# 1. Generate C sources from Vala library
echo "[1/4] Generating C sources from Vala..."
if [ ! -d "gen-c" ]; then
    ./gen_c_sources.sh
fi

# Run small patch on checked-in gen-c/libdvx3.c if present
if [ -f "gen-c/libdvx3.c" ]; then
    chmod +x scripts/patch-gen-c.sh || true
    scripts/patch-gen-c.sh gen-c/libdvx3.c || true
fi

# 2. Compile generated C code
echo "[2/4] Compiling C library..."
gcc -c gen-c/libdvx3.c -o libdvx3.o \
    $(pkg-config --cflags glib-2.0 gio-unix-2.0 json-glib-1.0 libsodium) \
    -I. -Wno-incompatible-pointer-types -Wno-discarded-qualifiers

# 3. Compile C++ backup manager
echo "[3/4] Compiling C++ backup manager..."
g++ -c backup-manager.cpp -o backup-manager-impl.o \
    -std=c++17 \
    $(pkg-config --cflags glib-2.0 gio-unix-2.0 json-glib-1.0 libsodium) \
    -I.

# 4. Link final executable
echo "[4/4] Linking backup-manager executable..."
g++ libdvx3.o backup-manager-impl.o -o backup-manager \
    $(pkg-config --libs glib-2.0 gio-unix-2.0 json-glib-1.0 libsodium) \
    -lstdc++fs

echo ""
echo "✓ Build complete!"
echo ""
echo "Run with: ./backup-manager"
echo "Or non-interactive: ./backup-manager <command>"
echo ""
echo "Commands:"
echo "  ./backup-manager list        - List all backup jobs"
echo "  ./backup-manager status      - Show backup status"
echo "  ./backup-manager history     - View backup history"
echo "  ./backup-manager run <job>   - Run specific backup job"
echo "  ./backup-manager cleanup     - Remove old backups"
echo ""
