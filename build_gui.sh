#!/bin/bash
# build_gui.sh - Build the Qt6 GUI for Backup Manager

set -e

# Use CC/CXX environment variables if set, otherwise default to gcc/g++
CC_COMPILER=${CC:-gcc}
CXX_COMPILER=${CXX:-g++}

echo "Building Backup Manager GUI..."

# Check for Qt6
if ! pkg-config --exists Qt6Widgets; then
    echo "Error: Qt6 not found. Install with:"
    echo "  Arch Linux: sudo pacman -S qt6-base"
    echo "  Debian/Ubuntu: sudo apt-get install qt6-base-dev"
    exit 1
fi

# Check for json-glib-1.0
if ! pkg-config --exists json-glib-1.0; then
    echo "Error: json-glib-1.0 not found. Install with:"
    echo "  Arch Linux: sudo pacman -S json-glib"
    echo "  Debian/Ubuntu: sudo apt-get install libjson-glib-dev"
    exit 1
fi

# Check for libsodium
if ! pkg-config --exists libsodium; then
    echo "Error: libsodium not found. Install with:"
    echo "  Arch Linux: sudo pacman -S libsodium"
    echo "  Debian/Ubuntu: sudo apt-get install libsodium-dev"
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

"$CC_COMPILER" -c -fPIC gen-c/libdvx3.c -o libdvx3.o \
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

"$CC_COMPILER" $SHARED_FLAGS -o libdvx3.$SHARED_EXT libdvx3.o \
    $(pkg-config --libs glib-2.0 $GIO_LIBS json-glib-1.0 libsodium)

# 3. Compile backup-manager implementation
echo "[3/5] Compiling backup manager library..."
"$CXX_COMPILER" -c -fPIC backup-manager.hpp -o backup-manager-lib.o \
    -std=c++17 \
    $(pkg-config --cflags glib-2.0 $GIO_LIBS json-glib-1.0 libsodium) \
    -I.

# 4. Run MOC on GUI header
echo "[4/5] Running Qt MOC..."

# Windows MSYS2 fix for Qt6 moc path from pkg-config libexecdir
case "$UNAME_OUT" in
  MINGW*|MSYS*|CYGWIN*)
    if command -v pkg-config >/dev/null 2>&1; then
      libexecdir=$(pkg-config --variable=libexecdir 'Qt6Core >= 6.4.0' 2>/dev/null)
      if [ -n "$libexecdir" ]; then
        libexecdir=$(cygpath -a "$libexecdir")
        moc_candidate="$libexecdir/moc"
        if [ -x "$moc_candidate" ] || [ -x "$moc_candidate.exe" ]; then
          if [ -x "$moc_candidate" ]; then
            MOC="$moc_candidate"
          else
            MOC="${moc_candidate}.exe"
          fi
          RCC="${libexecdir}/rcc"
          echo "✓ Found moc at Qt6 libexecdir: $MOC"
        fi
      fi
    fi
    ;;
esac

# Find moc and rcc (works on Linux, macOS, Windows/MSYS2)
# Prioritize Qt6-specific tools to avoid Qt5/Qt6 mismatch
if [ -z "$MOC" ]; then
  if [ -n "$QT_MOC_NATIVE" ] && [ -x "$QT_MOC_NATIVE" ]; then
    MOC="$QT_MOC_NATIVE"
    RCC_DIR=$(dirname "$QT_MOC_NATIVE")
    if [ -x "$RCC_DIR/rcc" ]; then
      RCC="$RCC_DIR/rcc"
    else
      RCC=rcc # Fallback to searching in PATH
    fi
  # Check macOS Homebrew paths (Apple Silicon and Intel)
  elif [ -x /opt/homebrew/opt/qt/bin/moc ]; then
    MOC=/opt/homebrew/opt/qt/bin/moc
    RCC=/opt/homebrew/opt/qt/bin/rcc
  elif [ -x /opt/homebrew/opt/qt@6/bin/moc ]; then
    MOC=/opt/homebrew/opt/qt@6/bin/moc
    RCC=/opt/homebrew/opt/qt@6/bin/rcc
  elif [ -x /usr/local/opt/qt/bin/moc ]; then
    MOC=/usr/local/opt/qt/bin/moc
    RCC=/usr/local/opt/qt/bin/rcc
  elif [ -x /usr/local/opt/qt@6/bin/moc ]; then
    MOC=/usr/local/opt/qt@6/bin/moc
    RCC=/usr/local/opt/qt@6/bin/rcc
  elif [ -x /opt/homebrew/bin/moc ]; then
    MOC=/opt/homebrew/bin/moc
    RCC=/opt/homebrew/bin/rcc
  elif [ -x /usr/local/bin/moc ]; then
    MOC=/usr/local/bin/moc
    RCC=/usr/local/bin/rcc
  # Check additional macOS Homebrew qt6 paths
  elif [ -x /opt/homebrew/opt/qt6/bin/moc ]; then
    MOC=/opt/homebrew/opt/qt6/bin/moc
    RCC=/opt/homebrew/opt/qt6/bin/rcc
  elif [ -x /usr/local/opt/qt6/bin/moc ]; then
    MOC=/usr/local/opt/qt6/bin/moc
    RCC=/usr/local/opt/qt6/bin/rcc
  # Check MSYS2/MINGW64 paths (Windows) - executables have .exe extension
  # Prioritize Qt6-specific variants first, check both with and without .exe
  elif [ -x /mingw64/bin/moc-qt6 ]; then
    MOC=/mingw64/bin/moc-qt6
    RCC=/mingw64/bin/rcc-qt6
    echo "✓ Found moc-qt6 at /mingw64/bin/"
  elif [ -x /mingw64/bin/moc-qt6.exe ]; then
    MOC=/mingw64/bin/moc-qt6.exe
    RCC=/mingw64/bin/rcc-qt6.exe
    echo "✓ Found moc-qt6.exe at /mingw64/bin/"
  elif [ -x /mingw64/bin/moc6 ]; then
    MOC=/mingw64/bin/moc6
    RCC=/mingw64/bin/rcc6
    echo "✓ Found moc6 at /mingw64/bin/"
  elif [ -x /mingw64/bin/moc6.exe ]; then
    MOC=/mingw64/bin/moc6.exe
    RCC=/mingw64/bin/rcc6.exe
    echo "✓ Found moc6.exe at /mingw64/bin/"
  elif [ -x /mingw64/bin/moc ]; then
    MOC=/mingw64/bin/moc
    RCC=/mingw64/bin/rcc
    echo "✓ Found moc at /mingw64/bin/"
  elif [ -x /mingw64/bin/moc.exe ]; then
    MOC=/mingw64/bin/moc.exe
    RCC=/mingw64/bin/rcc.exe
    echo "✓ Found moc.exe at /mingw64/bin/"
  elif [ -x /mingw64/qt6/bin/moc ]; then
    MOC=/mingw64/qt6/bin/moc
    RCC=/mingw64/qt6/bin/rcc
    echo "✓ Found moc at /mingw64/qt6/bin/"
  elif [ -x /mingw64/qt6/bin/moc.exe ]; then
    MOC=/mingw64/qt6/bin/moc.exe
    RCC=/mingw64/qt6/bin/rcc.exe
    echo "✓ Found moc.exe at /mingw64/qt6/bin/"
  elif [ -x /mingw64/lib/qt6/bin/moc ]; then
    MOC=/mingw64/lib/qt6/bin/moc
    RCC=/mingw64/lib/qt6/bin/rcc
    echo "✓ Found moc at /mingw64/lib/qt6/bin/"
  elif [ -x /mingw64/lib/qt6/bin/moc.exe ]; then
    MOC=/mingw64/lib/qt6/bin/moc.exe
    RCC=/mingw64/lib/qt6/bin/rcc.exe
    echo "✓ Found moc.exe at /mingw64/lib/qt6/bin/"
  # Check Linux paths
  elif [ -x /usr/lib/qt6/moc ]; then
    MOC=/usr/lib/qt6/moc
    RCC=/usr/lib/qt6/rcc
  elif [ -x /usr/lib/qt6/libexec/moc ]; then
    MOC=/usr/lib/qt6/libexec/moc
    RCC=/usr/lib/qt6/libexec/rcc
  # Check for Qt6-specific commands in PATH
  elif command -v moc-qt6 >/dev/null 2>&1; then
    MOC=moc-qt6
    RCC=rcc-qt6
  elif command -v moc6 >/dev/null 2>&1; then
    MOC=moc6
    RCC=rcc6
  # Fallback to generic commands in PATH
  elif command -v moc >/dev/null 2>&1; then
    MOC=moc
    RCC=rcc
  else
    echo "Error: moc not found. Install Qt6 development tools."
    echo "Searched locations:"
    echo "  - macOS Homebrew: /opt/homebrew/opt/qt/bin/moc, /opt/homebrew/opt/qt@6/bin/moc, /opt/homebrew/opt/qt6/bin/moc, /opt/homebrew/bin/moc"
    echo "  - macOS Homebrew (Intel): /usr/local/opt/qt/bin/moc, /usr/local/opt/qt@6/bin/moc, /usr/local/opt/qt6/bin/moc, /usr/local/bin/moc"
    echo "  - MSYS2: /mingw64/bin/moc, /mingw64/bin/moc.exe, /mingw64/qt6/bin/moc, /mingw64/qt6/bin/moc.exe, /mingw64/lib/qt6/bin/moc, /mingw64/lib/qt6/bin/moc.exe"
    echo "  - Linux: /usr/lib/qt6/moc, /usr/lib/qt6/libexec/moc"
    echo "  - PATH: moc-qt6, moc6, moc"
    exit 1
fi

$MOC backup-manager-gui.hpp -o backup-manager-gui.moc.cpp

echo "[4b/5] Compiling resources..."
if [ -f resources.qrc ] && [ -f dvx3-backup.png ]; then
    echo "Using dvx3-backup.png for resources"
    $RCC resources.qrc -o resources.rcc.cpp
elif [ -f resources.qrc ]; then
    echo "Warning: dvx3-backup.png not found; compiling resources without icon."
    $RCC resources.qrc -o resources.rcc.cpp
else
    echo "Warning: resources.qrc not found; icon will not be embedded."
    # Create an empty file to prevent the build from failing
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

"$CXX_COMPILER" -fPIC backup-manager-gui.cpp backup-manager-gui.moc.cpp resources.rcc.cpp \
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
if [ -f dvx3-backup.png ]; then
    echo "Icon embedded from dvx3-backup.png"
else
    echo "No icon found; place dvx3-backup.png in project root to customize icon."
fi
