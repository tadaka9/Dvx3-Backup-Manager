#!/bin/bash
# build_qt6_gui.sh - Build Dvx3 Backup Manager GUI with Qt6 (macOS/Windows)
set -e
set -o pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
RELEASE_DIR="${RELEASE_DIR:-Releases}"
ARTIFACT_PREFIX="${ARTIFACT_PREFIX:-Dvx3-Backup-Manager}"
TARGET_ARCH="${TARGET_ARCH:-x86_64}"

echo "=========================================="
echo "  Dvx3 Backup Manager - Qt6 GUI Build"
echo "=========================================="
echo ""
echo "Target Platform: $(uname -s)"
echo "Architecture: $TARGET_ARCH"
echo "Working Directory: $SCRIPT_DIR"
echo ""

# Create release directories
mkdir -p "$RELEASE_DIR/mac/${TARGET_ARCH}"
mkdir -p "$RELEASE_DIR/windows/${TARGET_ARCH}"

echo "[1/4] Checking Qt6 dependencies..."

# Check for qt@6 package (Homebrew on macOS)
QT_PATH=$(brew --prefix qt@6 2>/dev/null || echo "")

if [ -n "$QT_PATH" ] && [ -d "$QT_PATH" ]; then
    QT_VERSION=$(cat "$QT_PATH/VERSION")
    echo "✓ Qt6 found at $QT_PATH (version: $QT_VERSION)"
    QT_FLAGS="--qt-path=$QT_PATH"
else
    echo "❌ Error: Qt6 not found. Install Qt6 for macOS/Windows GUI."
    echo ""
    echo "Install instructions:"
    echo "  macOS: brew install qt@6"
    echo "  Windows (MSYS2): pacman -S mingw-w64-x86_64-qt6-base"
    exit 1
fi

# Check for CMake
if ! command -v cmake &>/dev/null; then
    echo "❌ Error: CMake not found. Install CMake."
    exit 1
fi
cmake_version=$(cmake --version | head -1)
echo "✓ CMake version: $cmake_version"

# Check for qtchooser (for multiple Qt installations)
if command -v qtchooser &>/dev/null; then
    echo "✓ qtchooser found, will use as default Qt6 launcher"
    QT_CHOOSER_FLAG="--qt-chooser"
else
    echo "⚠️  qtchooser not found. Will use direct Qt6 path."
fi

echo ""
echo "[2/4] Detecting platform and building dependencies..."

UNAME_OUT="$(uname -s)"
case "$UNAME_OUT" in
    MINGW*|MSYS*|CYGWIN*)
        PLATFORM="windows"
        echo "✓ Detected platform: Windows"
        # Install MSYS2 toolchain if needed
        if [ ! -d "/msys64" ]; then
            echo "Installing MSYS2 toolchain..."
            pacman -S --noconfirm mingw-w64-x86_64-qt6-base mingw-w64-x86_64-cmake mingw-w64-x86_64-glib mingw-w64-x86_64-json-glib \
                mingw-w64-x86_64-libsodium pkgconf vala dos2unix zip 2>&1 | tail -5 || true
        fi
        ;;
    Darwin)
        PLATFORM="macos"
        echo "✓ Detected platform: macOS"
        # Install Qt6 and dependencies for macOS
        brew update || true
        brew install --quiet qt@6 cmake zip dos2unix 2>&1 | tail -5 || true
        QT_PATH=$(brew --prefix qt@6)
        echo "✓ Qt6 installed to: $QT_PATH"
        ;;
    Linux)
        PLATFORM="linux"
        echo "✓ Detected platform: Linux (using GTK4 path)"
        # For Linux, use GTK4 instead of Qt6
        echo "⚠️  Using GTK4 build path for Linux (Qt6 not typically needed on Linux)"
        echo "Run ./build_all.sh for Linux GUI build"
        exit 0
        ;;
    *)
        echo "❌ Error: Unknown platform '$UNAME_OUT'"
        exit 1
        ;;
esac

echo ""
echo "[3/4] Building CLI executable (required for GUI)..."

# Build CLI first (cross-platform compatible)
CLI_BIN="${SCRIPT_DIR}/cli_backup_manager"

valac \
    main.vala \
    libdvx3.vala \
    -H "${SCRIPT_DIR}/dvx3.h" \
    --pkg glib-2.0 \
    --pkg json-glib-1.0 \
    --vapidir="${SCRIPT_DIR}/vala-extra-vapis" \
    --pkg libsodium \
    -D POSIX \
    -o "${CLI_BIN}" \
    2>&1 | grep -i "error\|warning" || true

if [ ! -f "$CLI_BIN" ]; then
    echo "❌ Error: CLI build failed. Cannot build GUI without CLI."
    exit 1
fi

echo "✓ CLI executable created: ${CLI_BIN}"
ls -lh "$CLI_BIN"

echo ""
echo "[4/4] Building Qt6 GUI..."

# Create CMake build directory
GUI_BUILD_DIR="${SCRIPT_DIR}/gui/qt-build"
rm -rf "$GUI_BUILD_DIR"
mkdir -p "$GUI_BUILD_DIR"

# Configure CMake
cd "$GUI_BUILD_DIR"
cmake .. \
    $QT_FLAGS \
    -DCMAKE_BUILD_TYPE=Release \
    -DCMAKE_INSTALL_PREFIX="${SCRIPT_DIR}" \
    -DCLI_EXECUTABLE="${CLI_BIN}" \
    2>&1 | grep -i "error\|warning" || true

# Build GUI
cmake --build . --target backup-manager-qtdesktop -j$(nproc) 2>&1 | tail -50

# Copy CLI to output directory
if [ -f "$CLI_BIN" ]; then
    cp "$CLI_BIN" "${SCRIPT_DIR}/gui/qt-build/bin/" || true
fi

echo "✓ Qt6 GUI build complete"
ls -lh "${GUI_BUILD_DIR}" 2>/dev/null || echo "No output in ${GUI_BUILD_DIR}"

echo ""
echo "=========================================="
echo "  Qt6 Build Complete!"
echo "=========================================="
