# Multi-Platform Build Guide for DVX3 Backup Manager

## Supported Platforms

1. **Linux x86_64** (AppImage)
2. **macOS** (Intel & Apple Silicon)
3. **Windows** (x64)
4. **Raspberry Pi** (ARMv7/32-bit & ARM64/64-bit)

---

## Prerequisites by Platform

### Linux (Build Host)
```bash
# Install build tools
sudo apt install -y valac gcc g++ make cmake pkg-config \
    libglib2.0-dev libjson-glib-dev libsodium-dev \
    qt6-base-dev qt6-base-dev-tools

# For AppImage creation
wget https://github.com/AppImage/AppImageKit/releases/download/continuous/appimagetool-x86_64.AppImage
chmod +x appimagetool-x86_64.AppImage
```

### macOS
```bash
# Install Homebrew, then:
brew install vala glib json-glib libsodium qt@6 cmake pkg-config
```

### macOS Apple Silicon (ARM64)
Prefer building on an ARM-based macOS machine (Apple Silicon) or run on a CI runner with arm64. When installing Homebrew packages for ARM64, ensure you use the correct brew prefix (e.g., /opt/homebrew):
```bash
# For Apple Silicon use the ARM brew prefix
eval "$(/opt/homebrew/bin/brew shellenv)"
brew install vala glib json-glib libsodium qt@6 cmake pkg-config
```

### Windows (Cross-compile from Linux)
```bash
# Install MinGW cross-compiler
sudo apt install -y mingw-w64 wine64

For packaging the GUI with Qt runtime DLLs on Windows, the following tools are useful (on a native MSYS2/MinGW environment):

```bash
# MSYS2 (MINGW64) packages
pacman -S mingw-w64-x86_64-qt6-tools nsis upx

# Use windeployqt (from Qt tools) to gather DLLs and plugin dependencies
windeployqt --dir build/Releases backup-manager-gui.exe

# Then create a ZIP or NSIS installer using the files in build/Releases
makensis -V2 -DOUTDIR=$(pwd)/Releases -DINPUTZIP=build/Releases.zip installer/windows-installer.nsi
```

### Windows MSVC (native, x64 / ARM64)
If you build on Windows with MSVC (Visual Studio), prefer `vcpkg` to install native dependencies and use `cmake -A ARM64` to build targetting ARM64. Example usage on a Windows host (PowerShell):
```powershell
git clone https://github.com/microsoft/vcpkg.git vcpkg
.\vcpkg\bootstrap-vcpkg.bat
.\vcpkg\vcpkg integrate install
.\vcpkg\vcpkg install libsodium zstd --triplet arm64-windows
cmake -S . -B build-msvc -G "Visual Studio 17 2022" -A ARM64 -DCMAKE_TOOLCHAIN_FILE=./vcpkg/scripts/buildsystems/vcpkg.cmake -DVCPKG_TARGET_TRIPLET=arm64-windows
cmake --build build-msvc --config Release
ctest -C Release --output-on-failure
```

### Windows ARM64 (Cross-compile or Native Build)
Producing a Windows ARM64 (win64-aarch64) artifact is best done on a native Windows ARM64 environment, but there are other options:

1) Native Windows ARM64 build (recommended):
  - Use a native Windows ARM64 machine or self-hosted runner with MSYS2 or Visual Studio installed.
  - Install MSYS2 aarch64 packages:
    ```powershell
    pacman -Syu
    pacman -S --noconfirm mingw-w64-aarch64-toolchain mingw-w64-aarch64-vala mingw-w64-aarch64-qt6-base mingw-w64-aarch64-qt6-tools mingw-w64-aarch64-pkgconf
    ```
  - Build using the aarch64 MinGW toolchain or Visual Studio ARM64 toolchain as appropriate.

2) Cross-compile from Linux (experimental):
  - You may try to cross-compile using mingw-w64 cross toolchains or `aarch64-w64-mingw32-gcc` if available:
    ```bash
    sudo apt-get install -y gcc-aarch64-linux-gnu g++-aarch64-linux-gnu mingw-w64
    # Configure and use a CMake toolchain that targets aarch64-w64-mingw32
    ```
  - Cross-compiling Qt-based GUI apps for Windows ARM64 requires an ARM64-built Qt and proper linking of platform plugins; this is non-trivial.

3) CI / Runners:
  - GitHub-hosted `windows-latest` uses x86_64 hosts. To both build and run tests for ARM64 Windows artifacts you will need a self-hosted `windows-arm64` runner or a build farm that provides ARM64 Windows hosts.

```

### Raspberry Pi
```bash
# On Raspberry Pi OS:
sudo apt install -y valac gcc libglib2.0-dev libjson-glib-dev \
    libsodium-dev qt6-base-dev
```

---

## Build Scripts

### 1. Linux AppImage

Create `build-appimage.sh`:
```bash
#!/bin/bash
set -e

VERSION="1.0.0"
APPDIR="DVX3BackupManager.AppDir"

echo "Building DVX3 Backup Manager AppImage..."

# Clean previous build
rm -rf "$APPDIR" *.AppImage

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
QT_PLUGIN_PATH=$(qmake6 -query QT_INSTALL_PLUGINS)
mkdir -p "$APPDIR/usr/plugins"
cp -r "$QT_PLUGIN_PATH/platforms" "$APPDIR/usr/plugins/" || true
cp -r "$QT_PLUGIN_PATH/styles" "$APPDIR/usr/plugins/" || true

# Copy library dependencies
copy_deps() {
    local binary=$1
    ldd "$binary" | grep "=> /" | awk '{print $3}' | while read lib; do
        if [[ ! -f "$APPDIR/usr/lib/$(basename $lib)" ]]; then
            # Skip system libraries
            if [[ ! "$lib" =~ ^/lib/x86_64 ]] && [[ ! "$lib" =~ ^/usr/lib/x86_64 ]]; then
                cp "$lib" "$APPDIR/usr/lib/" 2>/dev/null || true
            fi
        fi
    done
}

copy_deps "$APPDIR/usr/bin/backup-manager-gui"

# Create desktop file
cat > "$APPDIR/usr/share/applications/dvx3-backup.desktop" << 'EOF'
[Desktop Entry]
Type=Application
Name=DVX3 Backup Manager
Comment=Quantum Backup System with Encryption
Exec=backup-manager-gui
Icon=dvx3-backup
Categories=System;Utility;Archiving;
Terminal=false
EOF

# Create icon (placeholder - replace with actual icon)
cat > "$APPDIR/usr/share/icons/hicolor/256x256/apps/dvx3-backup.png" << 'EOF'
iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNk+M9QDwADhgGAWjR9awAAAABJRU5ErkJggg==
EOF

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

# Build AppImage
./appimagetool-x86_64.AppImage "$APPDIR" "DVX3-BackupManager-${VERSION}-x86_64.AppImage"

echo "✓ AppImage created: DVX3-BackupManager-${VERSION}-x86_64.AppImage"
```

### 2. macOS Universal Binary

Create `build-macos.sh`:
```bash
#!/bin/bash
set -e

VERSION="1.0.0"
APP_NAME="DVX3 Backup Manager"
BUNDLE_ID="com.dvx3.backupmanager"
BUNDLE_DIR="DVX3BackupManager.app"

echo "Building macOS application..."

# Build for Intel (x86_64)
valac --pkg glib-2.0 --pkg json-glib-1.0 --pkg sodium \
    main.vala -o main-x86_64 --target-glib=2.56 \
    -X -arch -X x86_64

# Build for Apple Silicon (arm64)
valac --pkg glib-2.0 --pkg json-glib-1.0 --pkg sodium \
    main.vala -o main-arm64 --target-glib=2.56 \
    -X -arch -X arm64

# Create universal binary
lipo -create main-x86_64 main-arm64 -output dvx3-universal

# Compile C++ library
g++ -c -fPIC backup-manager.cpp -o backup-manager.o \
    $(pkg-config --cflags glib-2.0 json-glib-1.0)
g++ -shared -o libbackup.dylib backup-manager.o \
    $(pkg-config --libs glib-2.0 json-glib-1.0)

# Compile Qt GUI
/opt/homebrew/bin/moc backup-manager-gui.hpp -o moc_backup-manager-gui.cpp
g++ -std=c++17 -o backup-manager-gui \
    backup-manager-gui.cpp moc_backup-manager-gui.cpp \
    $(pkg-config --cflags --libs Qt6Widgets glib-2.0 json-glib-1.0 libsodium) \
    -L. -lbackup

# Create app bundle structure
rm -rf "$BUNDLE_DIR"
mkdir -p "$BUNDLE_DIR/Contents/MacOS"
mkdir -p "$BUNDLE_DIR/Contents/Resources"
mkdir -p "$BUNDLE_DIR/Contents/Frameworks"

# Copy binaries
cp backup-manager-gui "$BUNDLE_DIR/Contents/MacOS/"
cp libbackup.dylib "$BUNDLE_DIR/Contents/Frameworks/"
cp dvx3-universal "$BUNDLE_DIR/Contents/MacOS/dvx3"

# Copy Qt frameworks
macdeployqt "$BUNDLE_DIR" -verbose=2

# Create Info.plist
cat > "$BUNDLE_DIR/Contents/Info.plist" << EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key>
    <string>backup-manager-gui</string>
    <key>CFBundleIdentifier</key>
    <string>${BUNDLE_ID}</string>
    <key>CFBundleName</key>
    <string>${APP_NAME}</string>
    <key>CFBundleVersion</key>
    <string>${VERSION}</string>
    <key>CFBundleShortVersionString</key>
    <string>${VERSION}</string>
    <key>NSHighResolutionCapable</key>
    <true/>
</dict>
</plist>
EOF

# Create DMG
hdiutil create -volname "${APP_NAME}" -srcfolder "$BUNDLE_DIR" \
    -ov -format UDZO "DVX3-BackupManager-${VERSION}.dmg"

echo "✓ macOS app created: DVX3-BackupManager-${VERSION}.dmg"
```

### 3. Windows Installer

Create `build-windows.sh`:
```bash
#!/bin/bash
set -e

VERSION="1.0.0"
MINGW_PREFIX="x86_64-w64-mingw32"

echo "Cross-compiling for Windows..."

# Build Vala to C
valac --pkg glib-2.0 --pkg json-glib-1.0 --pkg sodium \
    main.vala -C -d build/gen-c-win

# Cross-compile C code
${MINGW_PREFIX}-gcc -c gen-c-win/*.c \
    -I/usr/${MINGW_PREFIX}/include/glib-2.0 \
    -I/usr/${MINGW_PREFIX}/lib/glib-2.0/include

${MINGW_PREFIX}-gcc -o dvx3.exe *.o \
    -lglib-2.0 -ljson-glib-1.0 -lsodium -lws2_32

# Cross-compile C++ components
${MINGW_PREFIX}-g++ -c backup-manager.cpp \
    -I/usr/${MINGW_PREFIX}/include

${MINGW_PREFIX}-g++ -shared -o libbackup.dll backup-manager.o \
    -lglib-2.0 -ljson-glib-1.0

# Build Qt GUI (requires Qt for MinGW)
# Note: This is complex - easier to build on actual Windows
# Or use MXE (M cross environment)

echo "Note: Qt GUI for Windows best built on native Windows or with MXE"
echo "✓ CLI tools built for Windows"
```

### 4. Raspberry Pi (ARM)

Create `build-raspberry.sh`:
```bash
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
    echo "Unsupported architecture: $ARCH"
    exit 1
fi

# Standard build
./build_gui.sh

# Create tarball
mkdir -p dvx3-backup-manager-${VERSION}-${PLATFORM}
cp backup-manager-gui dvx3-backup-manager-${VERSION}-${PLATFORM}/
cp libdvx3.so dvx3-backup-manager-${VERSION}-${PLATFORM}/
cp README.md dvx3-backup-manager-${VERSION}-${PLATFORM}/

cat > dvx3-backup-manager-${VERSION}-${PLATFORM}/run.sh << 'EOF'
#!/bin/bash
SCRIPT_DIR=$(dirname "$0")
cd "$SCRIPT_DIR"
export LD_LIBRARY_PATH=".:$LD_LIBRARY_PATH"
./backup-manager-gui "$@"
EOF
chmod +x dvx3-backup-manager-${VERSION}-${PLATFORM}/run.sh

tar czf dvx3-backup-manager-${VERSION}-${PLATFORM}.tar.gz \
    dvx3-backup-manager-${VERSION}-${PLATFORM}/

echo "✓ Raspberry Pi package: dvx3-backup-manager-${VERSION}-${PLATFORM}.tar.gz"
```

---

## Docker-based Cross-Compilation

Create `Dockerfile.multiplatform`:
```dockerfile
FROM ubuntu:22.04

ENV DEBIAN_FRONTEND=noninteractive

# Install build dependencies
RUN apt-get update && apt-get install -y \
    valac gcc g++ make cmake pkg-config \
    libglib2.0-dev libjson-glib-dev libsodium-dev \
    qt6-base-dev qt6-base-dev-tools \
    mingw-w64 \
    wget curl git \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /build
COPY . .

# Build for Linux
RUN ./build_gui.sh

# Build for Windows
RUN ./build-windows.sh

CMD ["/bin/bash"]
```

Create `build-all.sh`:
```bash
#!/bin/bash
set -e

echo "=== Building DVX3 Backup Manager for all platforms ==="

# Linux AppImage
if [ -f appimagetool-x86_64.AppImage ]; then
    echo "Building Linux AppImage..."
    ./build-appimage.sh
else
    echo "Skip AppImage (appimagetool not found)"
fi

# Raspberry Pi
if [[ "$(uname -m)" =~ arm ]]; then
    echo "Building for Raspberry Pi..."
    ./build-raspberry.sh
fi

# macOS (only on macOS)
if [[ "$OSTYPE" == "darwin"* ]]; then
    echo "Building for macOS..."
    ./build-macos.sh
fi

# Windows (cross-compile)
echo "Building for Windows..."
./build-windows.sh || echo "Windows build failed (expected on non-Linux)"

echo ""
echo "=== Build Summary ==="
ls -lh *.AppImage *.dmg *.tar.gz *.exe 2>/dev/null || true
```

---

## GitHub Actions CI/CD

Create `.github/workflows/build.yml`:
```yaml
name: Multi-Platform Build

on:
  push:
    tags:
      - 'v*'
  workflow_dispatch:

jobs:
  build-linux:
    runs-on: debian-24.04
    steps:
      - uses: actions/checkout@v3
      - name: Install dependencies
        run: |
          sudo apt-get update
          sudo apt-get install -y valac libglib2.0-dev libjson-glib-dev \
            libsodium-dev qt6-base-dev
      - name: Build
        run: ./build_gui.sh
      - name: Create AppImage
        run: ./build-appimage.sh
      - uses: actions/upload-artifact@v3
        with:
          name: linux-appimage
          path: '*.AppImage'

  build-macos:
    runs-on: macos-latest
    steps:
      - uses: actions/checkout@v3
      - name: Install dependencies
        run: brew install vala glib json-glib libsodium qt@6
      - name: Build
        run: ./build-macos.sh
      - uses: actions/upload-artifact@v3
        with:
          name: macos-dmg
          path: '*.dmg'

  build-windows:
    runs-on: windows-latest
    steps:
      - uses: actions/checkout@v3
      - name: Setup MSYS2
        uses: msys2/setup-msys2@v2
        with:
          update: true
          install: >-
            mingw-w64-x86_64-gcc
            mingw-w64-x86_64-vala
            mingw-w64-x86_64-glib2
            mingw-w64-x86_64-json-glib
            mingw-w64-x86_64-libsodium
            mingw-w64-x86_64-qt6
      - name: Build
        shell: msys2 {0}
        run: ./build_gui.sh
      - uses: actions/upload-artifact@v3
        with:
          name: windows-exe
          path: '*.exe'

  build-raspberry:
    runs-on: ubuntu-24.04
    strategy:
      matrix:
        arch: [armhf, arm64]
    steps:
      - uses: actions/checkout@v3
      - name: Setup QEMU
        uses: docker/setup-qemu-action@v2
      - name: Build for ${{ matrix.arch }}
        run: |
          docker run --rm --platform linux/${{ matrix.arch }} \
            -v $(pwd):/build debian:bullseye \
            /bin/bash -c "cd /build && ./build-raspberry.sh"
      - uses: actions/upload-artifact@v3
        with:
          name: raspberry-${{ matrix.arch }}
          path: '*.tar.gz'
```

---

## Quick Start

```bash
# Make scripts executable
chmod +x build-*.sh build-all.sh

# Build for current platform
./build_gui.sh

# Build for all platforms (where possible)
./build-all.sh

# Build specific platform
./build-appimage.sh      # Linux AppImage
./build-macos.sh         # macOS
./build-windows.sh       # Windows (cross-compile)
./build-raspberry.sh     # Raspberry Pi
```

## Linux release packaging

After building the Linux artifacts (`backup-manager-gui`, `backup-manager`, `dvx3`, and `libdvx3.so`), the repository includes a packaging script which bundles the binaries together with their runtime libraries into `Releases/linux` and creates convenient wrapper scripts.

Usage:
Notes:
- The packaging script will copy runtime libraries into `Releases/linux/lib`, but excludes some non-portable system libraries (e.g., `libsystemd`, `libcap`, `libgomp`) to avoid copying kernel/platform-specific components. If you need to include systemd-related functionality, use AppImage or install the appropriate libs on target systems.

CI details:
- The `build-linux` job now prefers the system `libsodium` shared library by default. The CI does not force static linking of `libsodium` anymore, to avoid linking non-PIC static archives into `libdvx3.so`.
- Local builds will automatically fall back to using the shared `libsodium` if a static `libsodium` archive is present but not compiled with -fPIC (linking non-PIC static libs into a shared `libdvx3` will fail). If you explicitly set `FORCE_STATIC_LIBSODIUM=1`, the build will abort if the static archive is not PIC; follow the error message to install or compile a PIC-enabled static `libsodium` (or see `scripts/build-libsodium-pic.sh` below for a helper).

CI caching and cross-arch
------------------------
To reduce CI run times, the workflow now includes several caching steps and cross-arch improvements:

- ccache caching for Linux and macOS builds (avoids recompilation of unchanged files)
- `vcpkg` package cache for Windows MSVC builds (reduces re-download time)
- apt package archive caching to speed up package installs on Ubuntu runners
- QEMU+Docker-based cross-arch builds for ARM64 and Raspberry Pi (armv6/armhf) are supported in CI

If you need to reproduce the CI workflow locally, install and configure `ccache` and `vcpkg` to reuse the caches described above. See the `build.yml` CI workflow for the exact caching keys and paths used.

Local development - build a PIC-enabled static libsodium (optional):

If you need to link `libsodium` statically (for packing portable artifacts), you can build a PIC-enabled static libsodium and install it to `/usr/local` using the helper script:

```bash
chmod +x scripts/build-libsodium-pic.sh
./scripts/build-libsodium-pic.sh --version 1.0.20 --prefix /usr/local
export FORCE_STATIC_LIBSODIUM=1
./build_gui.sh
```


```bash
chmod +x scripts/package-linux.sh
./scripts/package-linux.sh
# This creates Releases/linux containing:
# - backup-manager-gui, backup-manager, dvx3
# - libdvx3.so and a `lib/` folder with required shared libraries
# - run-gui.sh, run-backup-manager.sh, run-dvx3.sh wrappers
# - A tarball Releases/Dvx3-Backup-Manager-Linux.tar.gz
```

Run the GUI with the provided wrapper so it uses the bundled libraries:

```bash
cd Releases/linux
./run-gui.sh
```

And for CLI:

```bash
./run-dvx3.sh --help
./run-backup-manager.sh list
```

