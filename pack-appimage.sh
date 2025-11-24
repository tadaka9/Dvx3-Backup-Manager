#!/usr/bin/env bash
set -euo pipefail

# pack-appimage.sh - create an AppImage of the Dvx3 Backup Manager GUI with Qt bundled
# Requires: linuxdeployqt (https://github.com/probonopd/linuxdeployqt) and appimagetool

HERE=$(cd "$(dirname "$0")" && pwd)
BUILD_DIR="$HERE/build"
OUT_APPIMAGE="$HERE/Dvx3-Backup-Manager.AppImage"

echo "Building GUI in release mode..."
./build_gui.sh

if ! command -v linuxdeployqt >/dev/null 2>&1; then
  echo "linuxdeployqt not found. Please install it (download AppImage from https://github.com/probonopd/linuxdeployqt/releases)." >&2
  exit 1
fi

echo "Preparing AppDir..."
rm -rf AppDir
mkdir -p AppDir/usr/bin
mkdir -p AppDir/usr/libexec/qt6
mkdir -p AppDir/usr/share/qt6/resources
mkdir -p AppDir/usr/share/qt6/translations/qtwebengine_locales
cp -v ./backup-manager-gui AppDir/usr/bin/
cp -v resources.rcc AppDir/usr/bin/ || true

echo "Detecting Qt install locations..."
QMAKE=$(command -v qmake || true)
if [ -n "$QMAKE" ]; then
  QT_PREFIX=$($QMAKE -query QT_INSTALL_PREFIX 2>/dev/null || true)
  QT_BIN=$($QMAKE -query QT_INSTALL_BINS 2>/dev/null || true)
else
  QT_PREFIX="/usr"
  QT_BIN="/usr/bin"
fi

echo "Attempt to copy QtWebEngine resources & binaries into AppDir..."
WEB_PROC=""
if [ -n "$QT_BIN" ] && [ -x "$QT_BIN/QtWebEngineProcess" ]; then
  WEB_PROC="$QT_BIN/QtWebEngineProcess"
fi
if [ -z "$WEB_PROC" ]; then
  for c in /usr/libexec/qt6/QtWebEngineProcess /usr/lib/qt6/QtWebEngineProcess /usr/lib/qt/libexec/QtWebEngineProcess /usr/lib/qt6/libexec/QtWebEngineProcess /usr/lib64/qt6/libexec/QtWebEngineProcess; do
    if [ -x "$c" ]; then WEB_PROC="$c"; break; fi
  done
fi
if [ -n "$WEB_PROC" ]; then
  cp -v "$WEB_PROC" AppDir/usr/libexec/qt6/ || true
fi

WEB_RES=""
for c in "$QT_PREFIX/share/qt6/resources/qtwebengine_resources.pak" /usr/share/qt6/resources/qtwebengine_resources.pak /usr/share/qt/resources/qtwebengine_resources.pak /usr/lib/qt6/resources/qtwebengine_resources.pak; do
  if [ -f "$c" ]; then WEB_RES="$c"; break; fi
done
if [ -n "$WEB_RES" ]; then
  cp -v "$WEB_RES" AppDir/usr/share/qt6/resources/ || true
fi

WEB_LOCALES=""
for c in "$QT_PREFIX/share/qt6/translations/qtwebengine_locales" /usr/share/qt6/translations/qtwebengine_locales /usr/share/qt/translations/qtwebengine_locales; do
  if [ -d "$c" ]; then WEB_LOCALES="$c"; break; fi
done
if [ -n "$WEB_LOCALES" ]; then
  cp -rv "$WEB_LOCALES"/* AppDir/usr/share/qt6/translations/qtwebengine_locales/ || true
fi

echo "Creating AppRun wrapper to export paths..."
cat > AppDir/AppRun <<'EOF'
#!/bin/sh
HERE="$(dirname "$(readlink -f "$0")")"
export QTWEBENGINEPROCESS_PATH="$HERE/usr/libexec/qt6/QtWebEngineProcess"
export QTWEBENGINE_RESOURCES_PATH="$HERE/usr/share/qt6/resources"
export QTWEBENGINE_LOCALES_PATH="$HERE/usr/share/qt6/translations/qtwebengine_locales"
export QT_QPA_PLATFORM_PLUGIN_PATH="$HERE/usr/lib/plugins/platforms"
exec "$HERE/usr/bin/backup-manager-gui" "$@"
EOF
chmod +x AppDir/AppRun

echo "Running linuxdeployqt..."
linuxdeployqt AppDir/usr/bin/backup-manager-gui -appimage -verbose=0 || true

echo "AppImage should be at: $OUT_APPIMAGE (check AppDir or linuxdeployqt output)"

echo "Note: You may need to bundle QtWebEngine resources explicitly on some distros. If the WebEngine does not run in the AppImage, set QTWEBENGINEPROCESS_PATH and QTWEBENGINE_RESOURCES_PATH in the wrapper script or include the qtwebengine resources under AppDir/usr/share/qt6/resources/qtwebengine_resources.pak"

echo "Done."

exit 0
