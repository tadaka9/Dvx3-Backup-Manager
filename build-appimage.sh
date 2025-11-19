#!/usr/bin/env bash
# ==============================================================================
# build_appimage.sh – Assemble an AppImage for Dvx3 Backup Manager
#
# Features
# --------
# • Detects the installed ICU major version and creates matching soname links.
# • Copies ICU libraries, Qt6 plugins, and other non‑system shared libraries.
# • Generates a minimal AppDir (desktop file, icon, AppRun).
# • Downloads appimagetool on‑the‑fly if missing.
# • Fails fast with clear diagnostics when required files are absent.
#
# Prerequisites
# -------------
# • Debian/Ubuntu‑style system (dpkg, apt, wget, qmake6/qmake).
# • Built binaries: backup-manager-gui, libdvx3.so (and optionally dvx3-backup.png).
# ==============================================================================

set -euo pipefail               # Safer Bash settings
IFS=$'\n\t'
set -x
log "Script started (trace enabled)"

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
# 0️⃣ Sanity checks – make sure the required binaries exist
# -------------------------------------------------------------------------
[[ -x "$BIN" ]]   || error "Executable $BIN not found in $(pwd)"
[[ -f "$LIB" ]]   || error "Library $LIB not found in $(pwd)"
# Sanity check: binaries
[[ -x "$BIN" ]]   || error "Executable $BIN not found in $(pwd)"
log "Found binary: $BIN"
[[ -f "$LIB" ]]   || error "Library $LIB not found in $(pwd)"
log "Found library: $LIB"
# Icon is optional – we’ll create a placeholder if it’s missing later

# -------------------------------------------------------------------------
# 1️⃣ Detect ICU major version
# -------------------------------------------------------------------------
detect_icu_major() {
    # Try dpkg first (works on Debian/Ubuntu)
    if command -v dpkg-query >/dev/null; then
        local ver
        ver=$(dpkg-query -W -f='${Version}' libicu-dev 2>/dev/null || true)
        if [[ -n "$ver" ]]; then
            echo "${ver%%.*}"   # strip everything after the first dot
            return
        fi
    fi

    # Fallback: look at the highest versioned .so file we can find
    local highest
    highest=$(find /usr/lib /usr/lib/x86_64-linux-gnu -maxdepth 2 -name 'libicu*.so.*' \
              | sed -E 's/.*\.so\.([0-9]+).*/\1/' | sort -nr | head -n1 || true)
    [[ -n "$highest" ]] && echo "$highest"
}
ICU_MAJOR=$(detect_icu_major || true)
log "ICU_MAJOR set to: $ICU_MAJOR"

if [[ -n "$ICU_MAJOR" ]]; then
    log "Detected ICU major version: $ICU_MAJOR"
else
    warn "Could not determine ICU major version – will use generic symlink rules"
fi
log "ICU detection complete"

# -------------------------------------------------------------------------
# 2️⃣ Prepare AppDir skeleton
# -------------------------------------------------------------------------
log "Cleaning previous AppDir and AppImages"
rm -rf "$APPDIR" "${APPDIR%.*}.AppImage" *.AppImage

log "AppDir and AppImages cleaned"

mkdir -p "$APPDIR/usr/bin" "$APPDIR/usr/lib" \
         "$APPDIR/usr/share/applications" \
         "$APPDIR/usr/share/icons/hicolor/256x256/apps" \
         "$APPDIR/usr/plugins"
log "AppDir skeleton created"

# -------------------------------------------------------------------------
# 3️⃣ Copy our own binaries into the AppDir
# -------------------------------------------------------------------------
log "Copying application binaries"
cp "$BIN"   "$APPDIR/usr/bin/"
cp "$LIB"   "$APPDIR/usr/lib/"
log "Binaries copied"

# -------------------------------------------------------------------------
# 4️⃣ Copy ICU libraries and create correct soname symlinks
# -------------------------------------------------------------------------
ICU_SRC_DIRS=(
    "/usr/lib/x86_64-linux-gnu"
    "/usr/lib"
)

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

# ---- Create soname symlinks ------------------------------------------------
log "Creating soname symlinks for ICU"
if [[ -n "$ICU_MAJOR" ]]; then
    # Only link libraries that match the detected major version
    for lib in "$ICU_DST"/libicu*.so."$ICU_MAJOR"*; do
        [[ -e "$lib" ]] || continue
        base=$(basename "$lib")
        soname="${base%%.so*}.so"   # strip everything after the first .so
        ln -sf "$base" "$ICU_DST/$soname"
    done
else
    # Generic fallback – strip everything after the first .so
    for lib in "$ICU_DST"/libicu*.so.*; do
        [[ -e "$lib" ]] || continue
        base=$(basename "$lib")
        soname="${base%%.so*}.so"
        ln -sf "$base" "$ICU_DST/$soname"
    done
fi

# ---- Validate that the *unversioned* sonames exist -------------------------
log "Validating required ICU sonames"
REQUIRED_SONAMES=("libicui18n.so" "libicuuc.so" "libicudata.so")
missing=0
for soname in "${REQUIRED_SONAMES[@]}"; do
    if [[ ! -e "$ICU_DST/$soname" ]]; then
        error "Required ICU soname $soname is missing from $ICU_DST"
    fi
done
log "All required ICU sonames are present."

# -------------------------------------------------------------------------
# 5️⃣ Copy Qt6 plugins (platforms, styles, xcbglintegrations)
# -------------------------------------------------------------------------
QT_PLUGIN_PATH=$(qmake6 -query QT_INSTALL_PLUGINS 2>/dev/null ||
                qmake -query QT_INSTALL_PLUGINS 2>/dev/null ||
                echo "$QT_PLUGIN_PATH_DEFAULT")

if [[ -d "$QT_PLUGIN_PATH" ]]; then
    for sub in platforms styles xcbglintegrations; do
        if [[ -d "$QT_PLUGIN_PATH/$sub" ]]; then
            log "  → copying Qt plugin $sub"
            cp -r "$QT_PLUGIN_PATH/$sub" "$APPDIR/usr/plugins/"
        fi
    done
else
    warn "Qt plugin directory not found – some UI features may be missing."
fi

# -------------------------------------------------------------------------
# 6️⃣ Copy additional non‑system shared libraries required by the GUI
# -------------------------------------------------------------------------
copy_deps() {
    local binary=$1
    log "Scanning dependencies of $binary"
    # List only absolute paths (skip system libs like libc, libpthread, etc.)
    ldd "$binary" 2>/dev/null |
        awk '/=> \/.*\.so/ {print $3}' |
        while read -r lib; do
            [[ -f "$lib" ]] || continue
            libname=$(basename "$lib")
            # Only copy libraries that are not part of the base system
            if [[ "$lib" == *"/qt6/"* ]] ||
               [[ "$lib" == *"/glib-"* ]] ||
               [[ "$lib" == *"/json-glib-"* ]] ||
               [[ "$lib" == *"/libsodium-"* ]] ||
               [[ "$lib" == *"/pcre"* ]] ||
               [[ "$lib" == *"/ffi"* ]]; then
                if [[ ! -e "$APPDIR/usr/lib/$libname" ]]; then
                    log "  → copying $libname"
                    cp "$lib" "$APPDIR/usr/lib/"
                fi
            fi
        done
}
copy_deps "$APPDIR/usr/bin/$BIN"

# -------------------------------------------------------------------------
# 7️⃣ Desktop file and icon
# -------------------------------------------------------------------------
log "Creating desktop entry"
    cp "$ICON" "$APPDIR/usr/share/icons/hicolor/256x256/apps/dvx3-backup.png"
    log "Icon copied to AppDir"
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

# Icon – use supplied PNG or generate a tiny placeholder
if [[ -f "$ICON" ]]; then
    cp "$ICON" "$APPDIR/usr/share/icons/hicolor/256x256/apps/dvx3-backup.png"
else
    warn "Icon $ICON not found – creating a placeholder."
    convert -size 256x256 xc:'#00ffff' \
        "$APPDIR/usr/share/icons/hicolor/256x256/apps/dvx3-backup.png" 2>/dev/null ||
    printf '\x89PNG\r\n\x1a\n' > "$APPDIR/usr/share/icons/hicolor/256x256/apps/dvx3-backup.png"
fi

# -------------------------------------------------------------------------
# 8️⃣ AppRun wrapper (sets up environment for the bundled app)
# -------------------------------------------------------------------------
log "Generating AppRun script"
cat > "$APPDIR/AppRun" <<'EOF'
#!/usr/bin/env bash
HERE="$(dirname "$(readlink -f "$0")")"
export PATH="${HERE}/usr/bin:${PATH}"
export LD_LIBRARY_PATH="${HERE}/usr/lib:${LD_LIBRARY_PATH}"
export QT_PLUGIN_PATH="${HERE}/usr/plugins"
export QT_QPA_PLATFORM_PLUGIN_PATH="${HERE}/usr/plugins/platforms"
exec "${HERE}/usr/bin/backup-manager-gui" "$@"
EOF
chmod +x "$APPDIR/AppRun"

# Also copy desktop/icon to the top level (nice for some AppImage viewers)
cp "$APPDIR/usr/share/applications/dvx3-backup.desktop" "$APPDIR/"
cp "$APPDIR/usr/share/icons/hicolor/256x256/apps/dvx3-backup.png" "$APPDIR/"
log "Copied desktop and icon to AppDir root"

# -------------------------------------------------------------------------
# 9️⃣ Ensure libfuse2 is present (optional, only for informative message)
# -------------------------------------------------------------------------
if ! ldconfig -p 2>/dev/null | grep -q libfuse.so.2; then
    warn "libfuse2 is not installed – the resulting AppImage may require the user to install it."
    echo "You can install it with: sudo apt-get install -y libfuse2"
else
    log "libfuse2 is present."
fi
fi

# -------------------------------------------------------------------------
# 10️⃣ Download appimagetool if missing
# -------------------------------------------------------------------------
if [[ ! -f "$APPIMAGETOOL" ]]; then
    log "Downloading appimagetool..."
    wget -q "https://github.com/AppImage/AppImageKit/releases/download/continuous/$APPIMAGETOOL"
    chmod +x "$APPIMAGETOOL"
    log "appimagetool downloaded and made executable"
else
    log "appimagetool already present"
fi
fi

# -------------------------------------------------------------------------
# 11️⃣ Build the AppImage
# -------------------------------------------------------------------------
log "Building the AppImage…"
if [[ -e /dev/fuse ]]; then
    ARCH=x86_64 ./"$APPIMAGETOOL" "$APPDIR" "Dvx3-BackupManager-${VERSION}-x86_64.AppImage"
    log "AppImage build command completed (with FUSE)"
else
    warn "FUSE not available – falling back to --appimage-extract-and-run mode."
    ARCH=x86_64 ./"$APPIMAGETOOL" --appimage-extract-and-run \
        "$APPDIR" "Dvx3-BackupManager-${VERSION}-x86_64.AppImage"
    log "AppImage build command completed (extract-and-run)"
fi

log "✅ AppImage created successfully!"
ls -lh "Dvx3-BackupManager-${VERSION}-x86_64.AppImage"