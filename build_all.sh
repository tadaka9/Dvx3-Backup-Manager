#!/bin/bash
# build_all.sh - Build all targets for Dvx3 Backup Manager (CLI + GUI)
# Supports: Linux, macOS, Windows (via MSYS2/WSL)
set -e
set -o pipefail

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
RELEASE_DIR="${RELEASE_DIR:-Releases}"
ARTIFACT_PREFIX="${ARTIFACT_PREFIX:-Dvx3-Backup-Manager}"
TARGET_ARCH="${TARGET_ARCH:-x86_64}"

echo "=========================================="
echo "  Dvx3 Backup Manager - Cross-Platform Build"
echo "=========================================="
echo ""
echo "Target Platform: $(uname -s)"
echo "Architecture: $TARGET_ARCH"
echo "Working Directory: $SCRIPT_DIR"
echo ""

# Create release directory
mkdir -p "$RELEASE_DIR/linux/${TARGET_ARCH}"
mkdir -p "$RELEASE_DIR/mac/${TARGET_ARCH}"
mkdir -p "$RELEASE_DIR/windows/${TARGET_ARCH}"

echo "[1/6] Checking dependencies..."

# Check for valac
if ! command -v valac &>/dev/null; then
    echo "❌ Error: valac not found. Install Vala toolchain."
    exit 1
fi
valac_version=$(valac --version | head -1)
echo "✓ Vala version: $valac_version"

# Check for pkg-config
if ! command -v pkg-config &>/dev/null; then
    echo "❌ Error: pkg-config not found. Install pkg-config."
    exit 1
fi

# Check for GLib/json-glib dependencies
GLIB_CHECK=$(pkg-config --exists glib-2.0 && echo "yes" || echo "no")
JSON_GLIB_CHECK=$(pkg-config --exists json-glib-1.0 && echo "yes" || echo "no")
LIBSODIUM_CHECK=$(pkg-config --exists libsodium && echo "yes" || echo "no")

if [ "$GLIB_CHECK" = "no" ]; then
    echo "❌ Error: glib-2.0 not found via pkg-config"
    exit 1
fi
echo "✓ GLib version: $(pkg-config --modversion glib-2.0)"

if [ "$JSON_GLIB_CHECK" = "no" ]; then
    echo "❌ Error: json-glib-1.0 not found via pkg-config"
    exit 1
fi
echo "✓ json-glib version: $(pkg-config --modversion json-glib-1.0)"

if [ "$LIBSODIUM_CHECK" = "no" ]; then
    echo "❌ Error: libsodium not found via pkg-config"
    exit 1
fi
echo "✓ libsodium version: $(pkg-config --modversion libsodium)"

# Check for optional GTK4 (GUI build)
GTK_CHECK=$(pkg-config --exists gtk+-4.0 && echo "yes" || echo "no")
if [ "$GTK_CHECK" = "no" ]; then
    echo "⚠️  Warning: GTK+ 4.0 not found - will build CLI only, skip GUI build"
    BUILD_GUI=false
else
    echo "✓ GTK+ version: $(pkg-config --modversion gtk+-4.0)"
    echo "[+] GTK+ found - proceeding with GUI build..."
    BUILD_GUI=true
fi

echo ""
echo "[2/6] Detecting platform and setting up build environment..."

UNAME_OUT="$(uname -s 2>/dev/null || echo unknown)"
case "$UNAME_OUT" in
    MINGW*|MSYS*|CYGWIN*)
        PLATFORM="windows"
        ;;
    Darwin)
        PLATFORM="macos"
        ;;
    Linux)
        PLATFORM="linux"
        ;;
    *)
        PLATFORM="unknown"
        echo "❌ Error: Unknown platform '$UNAME_OUT' not supported"
        exit 1
        ;;
esac

echo "✓ Detected platform: $PLATFORM"

# Set GIO packages based on platform
case "$PLATFORM" in
    linux|macos)
        GIO_PKG="--pkg gio-unix-2.0"
        VALA_DEFINES="-D POSIX"
        ;;
    windows)
        GIO_PKG=""  # Windows uses gio-2.0 only (no Unix bindings)
        VALA_DEFINES=""
        ;;
esac

echo "✓ GIO packages: $GIO_PKG"
echo ""
echo "[3/6] Building library C sources from Vala..."

# Create build directory for generated C sources
BUILD_GEN_C_DIR="${SCRIPT_DIR}/build/gen-c"
rm -rf "$BUILD_GEN_C_DIR"
mkdir -p "$BUILD_GEN_C_DIR"

# Generate C bindings from Vala
valac \
    --pkg glib-2.0 \
    --pkg $GIO_PKG \
    --pkg json-glib-1.0 \
    --vapidir="${SCRIPT_DIR}/vala-extra-vapis" \
    --pkg libsodium \
    $VALA_DEFINES \
    libdvx3.vala \
    -C \
    -d "$BUILD_GEN_C_DIR" \
    2>&1 | grep -i "error\|warning" || true

if [ ! -f "${BUILD_GEN_C_DIR}/libdvx3.c" ]; then
    echo "❌ Error: C generation failed. libdvx3.c not created."
    exit 1
fi

echo "✓ Generated C sources in ${BUILD_GEN_C_DIR}"

# Patch generated C if patch script exists
if [ -f "${SCRIPT_DIR}/scripts/patch-gen-c.sh" ]; then
    chmod +x "${SCRIPT_DIR}/scripts/patch-gen-c.sh" || true
    "${SCRIPT_DIR}/scripts/patch-gen-c.sh" "$BUILD_GEN_C_DIR/libdvx3.c" 2>&1 || echo "⚠️  Patch skipped or failed (non-fatal)"
fi

echo ""
echo "[4/6] Compiling C library..."

# Compile generated C into object file
C_FLAGS="$(pkg-config --cflags glib-2.0 json-glib-1.0 libsodium)"
LIBS="$(pkg-config --libs glib-2.0 json-glib-1.0 libsodium)"

gcc $C_FLAGS \
    -c "${BUILD_GEN_C_DIR}/libdvx3.c" \
    -o "${SCRIPT_DIR}/gen-c/libdvx3.o" \
    -I"${SCRIPT_DIR}" \
    -Wno-incompatible-pointer-types \
    -Wno-discarded-qualifiers \
    -fPIC \
    2>&1 | grep -i "error\|warning" || true

if [ ! -f "${SCRIPT_DIR}/gen-c/libdvx3.o" ]; then
    echo "❌ Error: C compilation failed. libdvx3.o not created."
    exit 1
fi

echo "✓ Compiled C library (libdvx3.o)"

# Compile CLI executable from Vala source directly
echo ""
echo "[5/6] Building CLI executable..."

CLI_BIN="${SCRIPT_DIR}/cli_backup_manager"

valac \
    main.vala \
    libdvx3.vala \
    -H "${SCRIPT_DIR}/dvx3.h" \
    --pkg glib-2.0 \
    --pkg $GIO_PKG \
    --pkg json-glib-1.0 \
    --vapidir="${SCRIPT_DIR}/vala-extra-vapis" \
    --pkg libsodium \
    $VALA_DEFINES \
    --ccode-gen \
    -g:0 \
    -o "${CLI_BIN}.tmp.so" \
    2>&1 | grep -i "error\|warning" || true

if [ ! -f "${CLI_BIN}" ] && [ -f "${CLI_BIN}.tmp.so" ]; then
    mv "${CLI_BIN}.tmp.so" "${CLI_BIN}"
    rm -f "${CLI_BIN}.tmp.o" 2>/dev/null || true
fi

echo "✓ CLI executable created: ${CLI_BIN}"
ls -lh "$CLI_BIN"

# Build GUI application if GTK+ is available
if [ "$BUILD_GUI" = "true" ]; then
    echo ""
    echo "[6/6] Building GUI application..."
    
    # Create build directory for GUI
    mkdir -p "${SCRIPT_DIR}/build-gui"
    
    GUI_BIN="${SCRIPT_DIR}/dvx3-backup-manager"
    
    GTK_FLAGS="$(pkg-config --cflags gtk+-4.0 gio json-glib-1.0 libsodium)"
    GTK_LIBS="$(pkg-config --libs gtk+-4.0 gio json-glib-1.0 libsodium)"
    
    valac \
        gui/src/*.vala \
        libdvx3.vala \
        -H "${SCRIPT_DIR}/dvx3.h" \
        $GTK_FLAGS \
        $GTK_LIBS \
        --pkg gio-unix-2.0 \
        -g:0 \
        -o "$GUI_BIN" \
        2>&1 | grep -i "error\|warning" || true
    
    if [ ! -f "$GUI_BIN" ]; then
        echo "⚠️  Warning: GUI build failed (non-fatal). CLI-only mode."
    else
        echo "✓ GUI application created: ${GUI_BIN}"
        ls -lh "$GUI_BIN"
    fi
else
    echo "[6/6] Skipping GUI build (GTK+ not available)"
fi

# Copy LICENSE and README to release directory
echo ""
echo "[7/7] Preparing release artifacts..."

cp LICENSE "${SCRIPT_DIR}/gen-c/" 2>/dev/null || true
cp README.md "${SCRIPT_DIR}/gen-c/" 2>/dev/null || true

# Create tarball for Linux
CLI_REL="${RELEASE_DIR}/linux/${TARGET_ARCH}"
mkdir -p "$CLI_REL"
cp "${SCRIPT_DIR}/cli_backup_manager" "$CLI_REL/" 2>/dev/null || \
    echo "⚠️  CLI binary not found at ${SCRIPT_DIR}/cli_backup_manager"

if [ -f "$GUI_BIN" ]; then
    cp "$GUI_BIN" "$CLI_REL/dvx3-backup-manager" 2>/dev/null || true
fi

echo ""
echo "=========================================="
echo "  Build Complete!"
echo "=========================================="
echo ""
echo "Release artifacts:"
find "$RELEASE_DIR" -type f \( -name "*.tar.gz" -o -name "*.so" \) | head -10

echo ""
echo "Build summary:"
if [ -f "${CLI_BIN}" ]; then
    echo "  ✓ CLI: ${CLI_BIN} ($(ls -lh "${CLI_BIN}" | awk '{print $5}') bytes)"
else
    echo "  ✗ CLI binary not created"
fi

if [ "$BUILD_GUI" = "true" ] && [ -f "$GUI_BIN" ]; then
    echo "  ✓ GUI: ${GUI_BIN} ($(ls -lh "$GUI_BIN" | awk '{print $5}') bytes)"
else
    echo "  ⚠️  GUI skipped (GTK+ not available)"
fi

echo ""
echo "Platform: $PLATFORM, Architecture: $TARGET_ARCH"
echo "Vala version: $(valac --version | head -1)"
