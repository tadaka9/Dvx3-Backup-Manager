#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT"
[[ $(uname -s) == Linux ]] || { echo 'Linux packages must be built natively on Linux' >&2; exit 1; }
for file in build/bin/dvx3 build/bin/backup-manager build/bin/dvx3-backup-manager build/lib/libdvx3.so; do
  [[ -x $file || ( $file == *.so && -s $file ) ]] || { echo "Missing build output: $file" >&2; exit 1; }
done
version="${DVX3_PACKAGE_VERSION:-1.0.0}"
case "$(uname -m)" in x86_64) arch=x86_64; deb_arch=amd64 ;; aarch64|arm64) arch=arm64; deb_arch=arm64 ;; *) echo 'Unsupported Linux package architecture' >&2; exit 1 ;; esac
work="$ROOT/build/installers/linux-$arch"
payload="$work/root"
artifacts="$ROOT/build/artifacts"
rm -rf "$work"
mkdir -p "$payload/usr/bin" "$payload/usr/lib" "$payload/usr/share/applications" "$payload/usr/share/icons/hicolor/512x512/apps" "$payload/usr/share/metainfo" "$payload/usr/share/doc/dvx3" "$artifacts"
install -m 755 build/bin/dvx3 build/bin/backup-manager build/bin/dvx3-backup-manager "$payload/usr/bin/"
install -m 755 build/lib/libdvx3.so "$payload/usr/lib/"
install -m 644 packaging/io.github.tadaka9.dvx3.desktop "$payload/usr/share/applications/"
install -m 644 packaging/io.github.tadaka9.dvx3.metainfo.xml "$payload/usr/share/metainfo/"
install -m 644 gui/qt/qtdesktop/icons/logo.png "$payload/usr/share/icons/hicolor/512x512/apps/io.github.tadaka9.dvx3.png"
install -m 644 LICENSE README.md BUILD.md COMPRESSION.md "$payload/usr/share/doc/dvx3/"

build_deb() {
  command -v dpkg-deb >/dev/null || { echo 'dpkg-deb is required' >&2; exit 1; }
  local tree="$work/deb"
  cp -a "$payload" "$tree"
  mkdir -p "$tree/DEBIAN"
  sed -e "s/@VERSION@/$version/g" -e "s/@ARCH@/$deb_arch/g" packaging/linux/control.in > "$tree/DEBIAN/control"
  dpkg-deb --root-owner-group --build "$tree" "$artifacts/dvx3_${version}_${deb_arch}.deb"
  dpkg-deb --info "$artifacts/dvx3_${version}_${deb_arch}.deb" >/dev/null
}
build_rpm() {
  command -v rpmbuild >/dev/null || { echo 'rpmbuild is required' >&2; exit 1; }
  mkdir -p "$work/rpmbuild"/{BUILD,BUILDROOT,RPMS,SOURCES,SPECS,SRPMS}
  tar -C "$payload" -czf "$work/rpmbuild/SOURCES/dvx3-root.tar.gz" .
  rpmbuild --define "_topdir $work/rpmbuild" --define "dvx3_version $version" -bb packaging/linux/dvx3.spec
  find "$work/rpmbuild/RPMS" -name '*.rpm' -exec cp {} "$artifacts/" \;
  rpm -qip "$artifacts"/*.rpm >/dev/null
}
build_appimage() {
  [[ $arch == x86_64 ]] || { echo 'AppImage is verified only for Linux x86_64' >&2; exit 1; }
  command -v linuxdeploy >/dev/null || { echo 'linuxdeploy is required on PATH' >&2; exit 1; }
  local appdir="$work/DVX3.AppDir"
  cp -a "$payload" "$appdir"
  linuxdeploy --appdir "$appdir" --executable "$appdir/usr/bin/dvx3-backup-manager" --executable "$appdir/usr/bin/dvx3" --executable "$appdir/usr/bin/backup-manager" --desktop-file "$appdir/usr/share/applications/io.github.tadaka9.dvx3.desktop" --icon-file "$appdir/usr/share/icons/hicolor/512x512/apps/io.github.tadaka9.dvx3.png" --plugin qt --output appimage
  local image
  image="$(find . -maxdepth 1 -name '*.AppImage' -print -quit)"
  [[ -n $image && -s $image ]] || { echo 'linuxdeploy did not create an AppImage' >&2; exit 1; }
  mv "$image" "$artifacts/DVX3-${version}-${arch}.AppImage"
  chmod 755 "$artifacts/DVX3-${version}-${arch}.AppImage"
}
formats=("$@")
((${#formats[@]})) || formats=(deb rpm appimage)
for format in "${formats[@]}"; do
  case "$format" in deb) build_deb ;; rpm) build_rpm ;; appimage) build_appimage ;; *) echo "Unknown Linux package: $format" >&2; exit 1 ;; esac
done
