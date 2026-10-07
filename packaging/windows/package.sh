#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT"
[[ $(uname -s) == MINGW* || $(uname -s) == MSYS* ]] || { echo 'Windows packages must be built in MSYS2' >&2; exit 1; }
[[ ${MSYSTEM:-} == UCRT64 ]] || { echo 'Use MSYS2 UCRT64' >&2; exit 1; }
for tool in windeployqt.exe 7z.exe; do command -v "$tool" >/dev/null || { echo "Missing packaging tool: $tool" >&2; exit 1; }; done
version="${DVX3_PACKAGE_VERSION:-1.0.0}"
work="$ROOT/build/installers/windows-x86_64"
stage="$work/DVX3"
artifacts="$ROOT/build/artifacts"
rm -rf "$work"
mkdir -p "$stage" "$artifacts"
install -m 755 build/bin/dvx3.exe build/bin/backup-manager.exe build/bin/dvx3-backup-manager.exe build/bin/libdvx3.dll "$stage/"
windeployqt.exe --release --no-translations --dir "$stage" "$stage/dvx3-backup-manager.exe"
for _ in 1 2 3; do
  while IFS= read -r dll; do [[ -f "$stage/$(basename "$dll")" ]] || cp "$dll" "$stage/"; done < <(
    find "$stage" -maxdepth 1 \( -iname '*.exe' -o -iname '*.dll' \) -exec ldd {} + 2>/dev/null |
      awk '/=> \/ucrt64\/bin\// {print $3}' | sort -u
  )
done
cp LICENSE README.md "$stage/"
(cd "$work" && 7z.exe a -tzip "$artifacts/DVX3-${version}-windows-x86_64-portable.zip" DVX3 >/dev/null)
wix_bin='/c/Program Files (x86)/WiX Toolset v3.14/bin'
for tool in heat.exe candle.exe light.exe; do [[ -x "$wix_bin/$tool" ]] || { echo "Missing WiX tool: $wix_bin/$tool" >&2; exit 1; }; done
source_win="$(cygpath -w "$stage")"
"$wix_bin/heat.exe" dir "$source_win" -nologo -arch x64 -gg -sfrag -srd -sreg -dr INSTALLFOLDER -cg Dvx3Files -var var.SourceDir -out "$work/files.wxs"
"$wix_bin/candle.exe" -nologo -dSourceDir="$source_win" -out "$work/" packaging/windows/product.wxs "$work/files.wxs"
"$wix_bin/light.exe" -nologo -ext WixUIExtension -out "$artifacts/DVX3-${version}-windows-x86_64.msi" "$work/product.wixobj" "$work/files.wixobj"
[[ -s "$artifacts/DVX3-${version}-windows-x86_64.msi" ]]
