#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT"
[[ $(uname -s) == Darwin ]] || { echo 'macOS packages must be built natively on macOS' >&2; exit 1; }
for tool in macdeployqt dylibbundler productbuild iconutil sips ditto; do command -v "$tool" >/dev/null || { echo "Missing packaging tool: $tool" >&2; exit 1; }; done
for file in build/bin/dvx3-backup-manager build/bin/dvx3 build/bin/backup-manager; do [[ -x $file ]] || { echo "Missing build output: $file" >&2; exit 1; }; done
version="${DVX3_PACKAGE_VERSION:-1.0.0}"
case "$(uname -m)" in arm64) arch=arm64 ;; x86_64) arch=x86_64 ;; *) echo 'Unsupported macOS architecture' >&2; exit 1 ;; esac
work="$ROOT/build/installers/macos-$arch"
app="$work/DVX3 Backup Manager.app"
contents="$app/Contents"
artifacts="$ROOT/build/artifacts"
rm -rf "$work"
mkdir -p "$contents/MacOS" "$contents/Resources/bin" "$contents/Frameworks" "$artifacts"
install -m 755 build/bin/dvx3-backup-manager "$contents/MacOS/DVX3 Backup Manager"
install -m 755 build/bin/dvx3 build/bin/backup-manager "$contents/Resources/bin/"
sed -e "s/@VERSION@/$version/g" packaging/macos/Info.plist.in > "$contents/Info.plist"
iconset="$work/DVX3.iconset"
mkdir -p "$iconset"
for size in 16 32 128 256 512; do
  sips -z "$size" "$size" gui/qt/qtdesktop/icons/logo.png --out "$iconset/icon_${size}x${size}.png" >/dev/null
  double=$((size * 2))
  sips -z "$double" "$double" gui/qt/qtdesktop/icons/logo.png --out "$iconset/icon_${size}x${size}@2x.png" >/dev/null
done
iconutil -c icns "$iconset" -o "$contents/Resources/DVX3.icns"
macdeployqt "$app" -always-overwrite
dylibbundler -od -b -x "$contents/MacOS/DVX3 Backup Manager" -d "$contents/Frameworks" -p @executable_path/../Frameworks
codesign --force --deep --sign - "$app"
ditto -c -k --sequesterRsrc --keepParent "$app" "$artifacts/DVX3-${version}-macos-${arch}.app.zip"
productbuild --component "$app" /Applications "$artifacts/DVX3-${version}-macos-${arch}.pkg"
pkgutil --check-signature "$artifacts/DVX3-${version}-macos-${arch}.pkg" >/dev/null || true
