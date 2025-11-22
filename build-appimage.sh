#!/usr/bin/env bash
# ==============================================================================
# build_appimage.sh – Assemble an AppImage for Dvx3 Backup Manager
# ==============================================================================

set -euo pipefail
IFS=$'\n\t'

# -------------------------- Configuration ------------------------------------
VERSION="0.0.0-alpha_11162025"
APPDIR="Dvx3BackupManager.AppDir"
BIN="backup-manager-gui"
LIB="libdvx3.so"
ICON="dvx3-backup.png"
APPIMAGETOOL="appimagetool-x86_64.AppImage"
QT_PLUGIN_PATH_DEFAULT="/usr/lib/qt6/plugins"
# -------------------------------------------------------------------------

# -------------------------- Helper functions ---------------------------------
log()    { echo -e "\n[LOG $(date '+%H:%M:%S')] 🔎 $*"; }
error()  { echo -e "\n[ERR $(date '+%H:%M:%S')] ❌ $*" >&2; exit 1; }
warn()   { echo -e "\n[WRN $(date '+%H:%M:%S')] ⚠️  $*"; }

# -------------------------------------------------------------------------
# 0️⃣ Sanity checks
# -------------------------------------------------------------------------
[[ -x "$BIN" ]]   || error "Executable $BIN not found in $(pwd)"
log "Found binary: $BIN"
[[ -f "$LIB" ]]   || error "Library $LIB not found in $(pwd)"
log "Found library: $LIB"

# -------------------------------------------------------------------------
# 1️⃣ Detect ICU major version
# -------------------------------------------------------------------------
detect_icu_major() {
    # Try dpkg first
    if command -v dpkg-query >/dev/null; then
        local ver
        ver=$(dpkg-query -W -f='${Version}' libicu-dev 2>/dev/null || true)
        if [[ -n "$ver" ]]; then
            echo "${ver%%.*}"
            return
        fi
    fi

    # Fallback: find highest versioned .so
    local highest
    highest=$(find /usr/lib /usr/lib/x86_64-linux-gnu -maxdepth 2 -name 'libicu*.so.*' \
              | sed -E 's/.*\.so\.([0-9]+).*/\1/' | sort -nr | head -n1 || true)
    [[ -n "$highest" ]] && echo "$highest"
}

ICU_MAJOR=$(detect_icu_major || true)
if [[ -n "$ICU_MAJOR" ]]; then
    log "Detected ICU major version: $ICU_MAJOR"
else
    warn "Could not determine ICU major version – will use generic symlink rules"
fi

# -------------------------------------------------------------------------
# 2️⃣ Prepare AppDir skeleton
# -------------------------------------------------------------------------
log "Cleaning previous AppDir and AppImages"
rm -rf "$APPDIR" "${APPDIR%.*}.AppImage" *.AppImage

mkdir -p "$APPDIR/usr/bin" \
         "$APPDIR/usr/lib" \
         "$APPDIR/usr/share/applications" \
         "$APPDIR/usr/share/icons/hicolor/256x256/apps" \
         "$APPDIR/usr/plugins"
log "AppDir skeleton created"

# -------------------------------------------------------------------------
# 3️⃣ Copy our own binaries
# -------------------------------------------------------------------------
log "Copying application binaries"
cp "$BIN"   "$APPDIR/usr/bin/"
cp "$LIB"   "$APPDIR/usr/lib/"

# -------------------------------------------------------------------------
# 4️⃣ Copy ICU libraries
# -------------------------------------------------------------------------
ICU_SRC_DIRS=("/usr/lib/x86_64-linux-gnu" "/usr/lib")
ICU_DST="$APPDIR/usr/lib"
found_icu=0

for src in "${ICU_SRC_DIRS[@]}"; do
    if [[ -d "$src" ]]; then
        shopt -s nullglob
        icu_files=("$src"/libicu*.so*)
        shopt -u nullglob
        if (( ${#icu_files[@]} )); then
            log "  → copying ${#icu_files[@]} files from $src"
            cp "${icu_files[@]}" "$ICU_DST/"
            found_icu=1
        fi
    fi
done

(( found_icu )) || error "No ICU libraries found in any of ${ICU_SRC_DIRS[*]}"

# Create soname symlinks
log "Creating soname symlinks for ICU"
if [[ -n "$ICU_MAJOR" ]]; then
    for lib in "$ICU_DST"/libicu*.so."$ICU_MAJOR"*; do
        [[ -e "$lib" ]] || continue
        base=$(basename "$lib")
        soname="${base%%.so*}.so"
        ln -sf "$base" "$ICU_DST/$soname"
    done
else
    for lib in "$ICU_DST"/libicu*.so.*; do
        [[ -e "$lib" ]] || continue
        base=$(basename "$lib")
        soname="${base%%.so*}.so"
        ln -sf "$base" "$ICU_DST/$soname"
    done
fi

# Validate required sonames
REQUIRED_SONAMES=("libicui18n.so" "libicuuc.so" "libicudata.so")
for soname in "${REQUIRED_SONAMES[@]}"; do
    if [[ ! -e "$ICU_DST/$soname" ]]; then
        error "Required ICU soname $soname is missing from $ICU_DST"
    fi
done

# -------------------------------------------------------------------------
# 5️⃣ Copy Qt6 plugins
# -------------------------------------------------------------------------
QT_PLUGIN_PATH=$(qmake6 -query QT_INSTALL_PLUGINS 2>/dev/null ||
                qmake -query QT_INSTALL_PLUGINS 2>/dev/null ||
                echo "$QT_PLUGIN_PATH_DEFAULT")

if [[ -d "$QT_PLUGIN_PATH" ]]; then
    # Added imageformats (needed for icons) and iconengines
    for sub in platforms styles xcbglintegrations imageformats iconengines; do
        if [[ -d "$QT_PLUGIN_PATH/$sub" ]]; then
            log "  → copying Qt plugin $sub"
            cp -r "$QT_PLUGIN_PATH/$sub" "$APPDIR/usr/plugins/"
        fi
    done
else
    warn "Qt plugin directory not found – UI features may be missing."
fi

# -------------------------------------------------------------------------
# 6️⃣ Copy dependencies
# -------------------------------------------------------------------------
copy_deps() {
    local binary=$1
    log "Scanning dependencies of $binary"
    
    # Use ldd, filter out system libs (libc, libdl, etc), copy the rest
    ldd "$binary" 2>/dev/null | grep "=> /" | awk '{print $3}' | while read -r lib; do
        [[ -f "$lib" ]] || continue
        local libname
        libname=$(basename "$lib")

        # Exclusion list: Do NOT copy these system libraries
        if [[ "$libname" =~ ^(libc\.so|libstdc\+\+|libgcc_s|libpthread|libdl|libm|librt|libz|ld-linux) ]]; then
            continue
        fi

        if [[ ! -e "$APPDIR/usr/lib/$libname" ]]; then
            log "  → copying $libname"
            cp "$lib" "$APPDIR/usr/lib/"
        fi
    done
}
copy_deps "$APPDIR/usr/bin/$BIN"

# -------------------------------------------------------------------------
# 7️⃣ Desktop file and icon
# -------------------------------------------------------------------------
log "Creating desktop entry"
cat > "$APPDIR/usr/share/applications/dvx3-backup.desktop" <<'EOF'
[Desktop Entry]
Type=Application
Name=Dvx3 Backup Manager
Comment=Secure encrypted backup manager with Qt6 GUI
Exec=backup-manager-gui
Icon=dvx3-backup
Categories=System;Utility;Archiving;
Terminal=false
EOF

if [[ -f "$ICON" ]]; then
    cp "$ICON" "$APPDIR/usr/share/icons/hicolor/256x256/apps/dvx3-backup.png"
    log "Copied icon: $ICON"
else
    warn "Icon $ICON not found – AppImage will lack an icon."
fi

# -------------------------------------------------------------------------
# 8️⃣ Create AppRun script
# -------------------------------------------------------------------------
log "Creating AppRun script"
cat > "$APPDIR/AppRun" <<'EOF'
#!/bin/bash
HERE="$(dirname "$(readlink -f "${0}")")"
export LD_LIBRARY_PATH="${HERE}/usr/lib:${LD_LIBRARY_PATH:-}"
export QT_PLUGIN_PATH="${HERE}/usr/plugins:${QT_PLUGIN_PATH:-}"
export QT_QPA_PLATFORM_PLUGIN_PATH="${HERE}/usr/plugins/platforms:${QT_QPA_PLATFORM_PLUGIN_PATH:-}"
exec "${HERE}/usr/bin/backup-manager-gui" "$@"
EOF
chmod +x "$APPDIR/AppRun"

# -------------------------------------------------------------------------
# 9️⃣ Build the AppImage
# -------------------------------------------------------------------------
log "Building AppImage"
if [[ ! -f "$APPIMAGETOOL" ]]; then
    log "Downloading appimagetool..."
    wget -q "https://github.com/AppImage/AppImageKit/releases/download/continuous/appimagetool-x86_64.AppImage" -O "$APPIMAGETOOL"
    chmod +x "$APPIMAGETOOL"
fi

"./$APPIMAGETOOL" --no-appstream "$APPDIR" "Dvx3BackupManager-$VERSION-x86_64.AppImage"

log "AppImage created: Dvx3BackupManager-$VERSION-x86_64.AppImage"