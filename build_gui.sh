#!/bin/bash
# build_gui.sh - Build Dvx3 Backup Manager GUI with GTK4
set -e
set -o pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
RELEASE_DIR="${RELEASE_DIR:-Releases}"
TARGET_ARCH="${TARGET_ARCH:-x86_64}"

echo "[1/5] Checking dependencies..."

if ! command -v valac &>/dev/null; then
    echo "❌ Error: valac not found."
    exit 1
fi

GLIB_CHECK=$(pkg-config --exists glib-2.0 && echo "yes" || echo "no")
if [ "$GLIB_CHECK" = "no" ]; then
    echo "❌ Error: glib-2.0 not found"
    exit 1
fi

GIO_UNIX_CHECK=$(pkg-config --exists gio-unix-2.0 && echo "yes" || echo "no")
if [ "$GIO_UNIX_CHECK" = "no" ]; then
    echo "❌ Error: gio-unix-2.0 not found (required for GUI)"
    exit 1
fi

JSON_GLIB_CHECK=$(pkg-config --exists json-glib-1.0 && echo "yes" || echo "no")
if [ "$JSON_GLIB_CHECK" = "no" ]; then
    echo "❌ Error: json-glib-1.0 not found"
    exit 1
fi

GTK4_PKG="gtk+-4.0"
GTK_CHECK=$(pkg-config --exists "$GTK4_PKG" 2>/dev/null && echo "yes" || echo "no")
if [ "$GTK_CHECK" = "no" ]; then
    echo "❌ Error: GTK+ 4.0 not found (required for GUI)"
    exit 1
fi

LIBSODIUM_CHECK=$(pkg-config --exists libsodium && echo "yes" || echo "no")
if [ "$LIBSODIUM_CHECK" = "no" ]; then
    echo "❌ Error: libsodium not found"
    exit 1
fi

echo "✓ All dependencies found:"
echo "  glib-2.0: $(pkg-config --modversion glib-2.0)"
echo "  gio-unix-2.0: $(pkg-config --modversion gio-unix-2.0)"
echo "  json-glib-1.0: $(pkg-config --modversion json-glib-1.0)"
echo "  gtk+-4.0: $(pkg-config --modversion gtk+-4.0)"
echo "  libsodium: $(pkg-config --modversion libsodium)"

UNAME_OUT="$(uname -s 2>/dev/null || echo unknown)"
case "$UNAME_OUT" in
    MINGW*|MSYS*|CYGWIN*) PLATFORM="windows" ;;
    Darwin) PLATFORM="macos" ;;
    Linux) PLATFORM="linux" ;;
    *) PLATFORM="unknown"; exit 1 ;;
esac

echo ""
echo "[2/5] Detecting platform: $PLATFORM"

# Build shared library for Dvx3
echo "[3/5] Building libdvx3.so..."
LIB_OUTPUT_DIR="${SCRIPT_DIR}/build/lib"
rm -rf "$LIB_OUTPUT_DIR"
mkdir -p "$LIB_OUTPUT_DIR"

valac \
    --pkg glib-2.0 \
    --pkg gio-unix-2.0 \
    --pkg json-glib-1.0 \
    --vapidir="${SCRIPT_DIR}/vala-extra-vapis" \
    --pkg libsodium \
    -D POSIX \
    libdvx3.vala \
    --shared \
    --export-all-symbols \
    -o "${LIB_OUTPUT_DIR}/libdvx3.so" \
    2>&1 | grep -i "error\|warning" || true

echo "✓ Generated: ${LIB_OUTPUT_DIR}/libdvx3.so"
ls -lh "${LIB_OUTPUT_DIR}/libdvx3.so"

# Build GUI
echo "[4/5] Building GUI executable..."
GUI_BIN="${SCRIPT_DIR}/dvx3-backup-manager"

valac \
    gui/src/dashboard.vala \
    --pkg glib-2.0 \
    --pkg gio-unix-2.0 \
    --pkg json-glib-1.0 \
    --vapidir="${SCRIPT_DIR}/vala-extra-vapis" \
    --pkg libsodium \
    -D POSIX \
    --shared \
    -o "${GUI_BIN}" \
    $(pkg-config --cflags glib-2.0 gio-unix-2.0 json-glib-1.0) \
    $(pkg-config --libs glib-2.0 gio-unix-2.0 libsodium json-glib-1.0 gtk+-4.0) \
    -g:0 \
    2>&1 | grep -i "error" || true

if [ ! -f "${GUI_BIN}" ]; then
    echo "❌ Error: GUI build failed."
    exit 1
fi

echo "✓ GUI executable created: ${GUI_BIN}"
ls -lh "$GUI_BIN"

# Create desktop entry
echo "[5/5] Creating desktop entry..."
DESKTOP_FILE="${SCRIPT_DIR}/dvx3-backup-manager.desktop"
cat > "$DESKTOP_FILE" << 'EOF'
[Desktop Entry]
Version=1.0
Type=Application
Name=Dvx3 Backup Manager
Comment=Secure encrypted backup manager with integrity verification
Exec=dvx3-backup-manager
Icon=dvx3-backup
Terminal=false
Categories=Utility;Backup;
Keywords=backup;encrypt;security;dvx3;
EOF

echo "✓ Created desktop entry: ${DESKTOP_FILE}"

echo ""
echo "=========================================="
echo "  GUI Build Complete!"
echo "=========================================="
echo "GUI executable: ${GUI_BIN}"
echo "Platform: $PLATFORM, GTK+: $(pkg-config --modversion gtk+-4.0)"
