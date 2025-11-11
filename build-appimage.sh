#!/bin/bash
set -e

VERSION="1.0.0"
APPDIR="DVX3BackupManager.AppDir"

echo "Building Dvx3 Backup Manager AppImage..."

# Clean previous build
rm -rf "$APPDIR" Dvx3-BackupManager-*.AppImage

# Build the application
./build_gui.sh

# Create AppDir structure
mkdir -p "$APPDIR/usr/bin"
mkdir -p "$APPDIR/usr/lib"
mkdir -p "$APPDIR/usr/share/applications"
mkdir -p "$APPDIR/usr/share/icons/hicolor/256x256/apps"

# Copy binaries
cp backup-manager-gui "$APPDIR/usr/bin/"
cp libdvx3.so "$APPDIR/usr/lib/"

# Copy Qt plugins
QT_PLUGIN_PATH=$(qmake6 -query QT_INSTALL_PLUGINS 2>/dev/null || echo "/usr/lib/qt6/plugins")
if [ -d "$QT_PLUGIN_PATH" ]; then
    mkdir -p "$APPDIR/usr/plugins"
    [ -d "$QT_PLUGIN_PATH/platforms" ] && cp -r "$QT_PLUGIN_PATH/platforms" "$APPDIR/usr/plugins/"
    [ -d "$QT_PLUGIN_PATH/styles" ] && cp -r "$QT_PLUGIN_PATH/styles" "$APPDIR/usr/plugins/"
    [ -d "$QT_PLUGIN_PATH/xcbglintegrations" ] && cp -r "$QT_PLUGIN_PATH/xcbglintegrations" "$APPDIR/usr/plugins/"
fi

# Copy library dependencies (non-system libs)
copy_deps() {
    local binary=$1
    ldd "$binary" 2>/dev/null | grep "=> /" | awk '{print $3}' | while read lib; do
        if [ -f "$lib" ]; then
            local basename=$(basename "$lib")
            if [ ! -f "$APPDIR/usr/lib/$basename" ]; then
                # Copy Qt, GLib, and other non-system libraries
                if [[ "$lib" =~ libQt6 ]] || [[ "$lib" =~ libglib ]] || \
                   [[ "$lib" =~ libjson ]] || [[ "$lib" =~ libsodium ]] || \
                   [[ "$lib" =~ libpcre ]] || [[ "$lib" =~ libffi ]]; then
                    cp "$lib" "$APPDIR/usr/lib/" 2>/dev/null || true
                fi
            fi
        fi
    done
}

copy_deps "$APPDIR/usr/bin/backup-manager-gui"

# Create desktop file
cat > "$APPDIR/usr/share/applications/dvx3-backup.desktop" << 'EOF'
[Desktop Entry]
Type=Application
Name=Dvx3 Backup Manager
Comment=Quantum Backup System with Encryption
Exec=backup-manager-gui
Icon=dvx3-backup
Categories=System;Utility;Archiving;
Terminal=false
EOF

# Create simple icon (placeholder - 16x16 cyan square)
convert -size 256x256 xc:'#00ffff' "$APPDIR/usr/share/icons/hicolor/256x256/apps/dvx3-backup.png" 2>/dev/null || \
    echo -e "\x89PNG\x0D\x0A\x1A\x0A" > "$APPDIR/usr/share/icons/hicolor/256x256/apps/dvx3-backup.png"

# Create AppRun script
cat > "$APPDIR/AppRun" << 'EOF'
#!/bin/bash
SELF=$(readlink -f "$0")
HERE=${SELF%/*}
export PATH="${HERE}/usr/bin:${PATH}"
export LD_LIBRARY_PATH="${HERE}/usr/lib:${LD_LIBRARY_PATH}"
export QT_PLUGIN_PATH="${HERE}/usr/plugins"
export QT_QPA_PLATFORM_PLUGIN_PATH="${HERE}/usr/plugins/platforms"
exec "${HERE}/usr/bin/backup-manager-gui" "$@"
EOF
chmod +x "$APPDIR/AppRun"

# Create .desktop file in root
cp "$APPDIR/usr/share/applications/dvx3-backup.desktop" "$APPDIR/"
cp "$APPDIR/usr/share/icons/hicolor/256x256/apps/dvx3-backup.png" "$APPDIR/"

# Download appimagetool if not present
if [ ! -f appimagetool-x86_64.AppImage ]; then
    echo "Downloading appimagetool..."
    wget -q https://github.com/AppImage/AppImageKit/releases/download/continuous/appimagetool-x86_64.AppImage
    chmod +x appimagetool-x86_64.AppImage
fi

# Build AppImage (use --appimage-extract-and-run if FUSE is not available)
if [ -e /dev/fuse ]; then
    ARCH=x86_64 ./appimagetool-x86_64.AppImage "$APPDIR" "DVX3-BackupManager-${VERSION}-x86_64.AppImage"
else
    echo "FUSE not available, using --appimage-extract-and-run"
    ARCH=x86_64 ./appimagetool-x86_64.AppImage --appimage-extract-and-run "$APPDIR" "Dvx3-BackupManager-${VERSION}-x86_64.AppImage"
fi

echo ""
echo "✓ AppImage created successfully!"
ls -lh DVX3-BackupManager-${VERSION}-x86_64.AppImage
