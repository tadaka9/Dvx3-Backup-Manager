#!/bin/bash
set -e

ARCH=$(uname -m)
VERSION="1.0.0"

echo "Building for Raspberry Pi ($ARCH)..."

if [[ "$ARCH" == "armv7l" ]]; then
    PLATFORM="armhf"
elif [[ "$ARCH" == "aarch64" ]]; then
    PLATFORM="arm64"
else
    echo "Warning: Unknown architecture $ARCH, using generic name"
    PLATFORM="$ARCH"
fi

# Standard build
./build_gui.sh

# Create distribution directory
DIST_DIR="dvx3-backup-manager-${VERSION}-${PLATFORM}"
rm -rf "$DIST_DIR" "${DIST_DIR}.tar.gz"
mkdir -p "$DIST_DIR"

# Copy binaries
cp backup-manager-gui "$DIST_DIR/"
cp libdvx3.so "$DIST_DIR/"
cp backup-manager "$DIST_DIR/" 2>/dev/null || true

# Copy documentation
[ -f README.md ] && cp README.md "$DIST_DIR/"
[ -f BUILD_MULTIPLATFORM.md ] && cp BUILD_MULTIPLATFORM.md "$DIST_DIR/"

# Create launcher script
cat > "$DIST_DIR/run.sh" << 'EOF'
#!/bin/bash
SCRIPT_DIR=$(dirname "$(readlink -f "$0")")
cd "$SCRIPT_DIR"
export LD_LIBRARY_PATH=".:$LD_LIBRARY_PATH"
./backup-manager-gui "$@"
EOF
chmod +x "$DIST_DIR/run.sh"

# Create install script
cat > "$DIST_DIR/install.sh" << 'EOF'
#!/bin/bash
set -e

PREFIX="${PREFIX:-$HOME/.local}"
BIN_DIR="$PREFIX/bin"
LIB_DIR="$PREFIX/lib"
SHARE_DIR="$PREFIX/share/applications"

echo "Installing DVX3 Backup Manager to $PREFIX"

mkdir -p "$BIN_DIR" "$LIB_DIR" "$SHARE_DIR"

cp backup-manager-gui "$BIN_DIR/"
cp libdvx3.so "$LIB_DIR/"
[ -f backup-manager ] && cp backup-manager "$BIN_DIR/"

cat > "$SHARE_DIR/dvx3-backup.desktop" << DESKTOP
[Desktop Entry]
Type=Application
Name=DVX3 Backup Manager
Comment=Quantum Backup System
Exec=$BIN_DIR/backup-manager-gui
Icon=system-backup
Categories=System;Utility;
Terminal=false
DESKTOP

echo "✓ Installed successfully!"
echo "Run with: $BIN_DIR/backup-manager-gui"
EOF
chmod +x "$DIST_DIR/install.sh"

# Create tarball
tar czf "${DIST_DIR}.tar.gz" "$DIST_DIR"

echo ""
echo "✓ Raspberry Pi package created successfully!"
ls -lh "${DIST_DIR}.tar.gz"
echo ""
echo "Installation:"
echo "  tar xzf ${DIST_DIR}.tar.gz"
echo "  cd $DIST_DIR"
echo "  ./install.sh"
