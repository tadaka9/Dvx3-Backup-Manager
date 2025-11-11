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
rm -rf gen-c

# Detect platform for package selection
UNAME_OUT="$(uname -s 2>/dev/null || echo unknown)"
case "$UNAME_OUT" in
    MINGW*|MSYS*|CYGWIN*)
        # Windows: gio-2.0 only (no gio-unix)
        GIO_PKG="gio-2.0"
        VALA_DEFINES=""
        ;;
    *)
        # Linux/macOS: needs gio-unix-2.0 and POSIX define
        GIO_PKG="gio-2.0 --pkg gio-unix-2.0"
        VALA_DEFINES="-D POSIX"
        ;;
esac

valac --pkg glib-2.0 --pkg $GIO_PKG --pkg json-glib-1.0 \
    --vapidir=vala-extra-vapis --pkg libsodium \
    $VALA_DEFINES \
    libdvx3.vala -C -d gen-c

# 2. Compile generated C code
echo "[2/5] Compiling C library..."

# Set GIO libs based on platform
case "$UNAME_OUT" in
    MINGW*|MSYS*|CYGWIN*)
        GIO_LIBS="gio-2.0"
        ;;
    *)
        GIO_LIBS="gio-2.0 gio-unix-2.0"
        ;;
esac

gcc -c -fPIC gen-c/libdvx3.c -o libdvx3.o \
    $(pkg-config --cflags glib-2.0 $GIO_LIBS json-glib-1.0 libsodium) \
    -I.

# Shared library extension (UNAME_OUT already set above)
case "$UNAME_OUT" in
    MINGW*|MSYS*|CYGWIN*)
        SHARED_EXT="dll"
        SHARED_FLAGS="-shared -Wl,--out-implib,libdvx3.dll.a -Wl,--export-all-symbols"
        ;;
    Darwin)
        SHARED_EXT="dylib"
        SHARED_FLAGS="-dynamiclib -install_name @loader_path/libdvx3.dylib"
        ;;
    *)
        SHARED_EXT="so"
        SHARED_FLAGS="-shared"
        ;;
esac

gcc $SHARED_FLAGS -o libdvx3.$SHARED_EXT libdvx3.o \
    $(pkg-config --libs glib-2.0 $GIO_LIBS json-glib-1.0 libsodium)

# 3. Compile backup-manager implementation
echo "[3/5] Compiling backup manager library..."
g++ -c -fPIC backup-manager.hpp -o backup-manager-lib.o \
    -std=c++17 \
    $(pkg-config --cflags glib-2.0 $GIO_LIBS json-glib-1.0 libsodium) \
    -I.

# 4. Run MOC on GUI header
echo "[4/5] Running Qt MOC..."
# Find moc and rcc (works on Linux, macOS, Windows/MSYS2)
if command -v moc6 >/dev/null 2>&1; then
    MOC=moc6
    RCC=rcc6
elif command -v moc-qt6 >/dev/null 2>&1; then
    MOC=moc-qt6
    RCC=rcc-qt6
elif command -v moc >/dev/null 2>&1; then
    MOC=moc
    RCC=rcc
elif [ -x /usr/lib/qt6/libexec/moc ]; then
    MOC=/usr/lib/qt6/libexec/moc
    RCC=/usr/lib/qt6/libexec/rcc
else
    echo "Error: moc not found. Install Qt6 development tools."
    exit 1
fi

$MOC backup-manager-gui.hpp -o backup-manager-gui.moc.cpp

echo "[4b/5] Compiling resources..."
if [ -f resources.qrc ]; then
    $RCC resources.qrc -o resources.rcc.cpp
else
    echo "Warning: resources.qrc not found; icon will not be embedded"
    touch resources.rcc.cpp
fi

# 5. Compile and link GUI
echo "[5/5] Compiling Qt6 GUI..."
# Set platform-specific rpath
case "$UNAME_OUT" in
    MINGW*|MSYS*|CYGWIN*)
        RPATH_FLAGS=""
        ;;
    Darwin)
        RPATH_FLAGS="-Wl,-rpath,@executable_path"
        ;;
    *)
        RPATH_FLAGS="-Wl,-rpath,\$ORIGIN"
        ;;
esac

g++ -fPIC backup-manager-gui.cpp backup-manager-gui.moc.cpp resources.rcc.cpp \
    -o backup-manager-gui \
    -std=c++17 \
    $(pkg-config --cflags --libs Qt6Widgets glib-2.0 $GIO_LIBS json-glib-1.0 libsodium) \
    -L. -ldvx3 $RPATH_FLAGS \
    -I.

echo ""
echo "✓ Build complete!"
echo ""
echo "Run with: ./backup-manager-gui"
echo ""
if [ -f icon.png ]; then
    echo "Icon embedded from icon.png"
else
    echo "No icon.png found; place one in project root to customize icon."
fi
