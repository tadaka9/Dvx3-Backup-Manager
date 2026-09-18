# Build Instructions for Dvx3 Backup Manager

## Overview

This guide explains how to build the Dvx3 Backup Manager CLI tool, GUI application, and prepare release artifacts.

---

## Prerequisites

### System Dependencies

```bash
# Linux (Ubuntu/Debian based)
sudo apt update
sudo apt install -y \
    valac \
    gcc \
    g++ \
    pkg-config \
    libsodium-dev \
    glib2.0-dev \
    json-glib-dev \
    gir1.2-gtk-4.0 \
    libgtk-4-dev

# macOS (using Homebrew)
brew install valac gcc libsodium gtk4

# Windows (using vcpkg)
vcpkg install libsodium:x64-windows
vcpkg install glib:x64-windows
vcpkg install gtk3:x64-windows
```

---

## Building the CLI Tool

### Quick Build

```bash
cd /home/dvx3/Documenti/Programming/Vala/Dvx3-Backup-Manager

# Generate C sources (needed for cross-platform builds)
./gen_c_sources.sh

# Build using build script
./build_backup_manager.sh
```

### Manual Build

```bash
# 1. Generate C sources from Vala
valac --vapidir=vala-extra-vapis \
      --pkg glib-2.0 \
      --pkg gio-unix-2.0 \
      --pkg json-glib-1.0 \
      --pkg posix \
      --pkg libsodium \
      --ccode \
      --directory=gen-c \
      --library=dvx3 \
      --vapi=dvx3.vapi \
      --header=dvx3.h \
      libdvx3.vala

# 2. Compile generated C library
gcc -c gen-c/libdvx3.c -o libdvx3.o \
    $(pkg-config --cflags glib-2.0 gio-unix-2.0 json-glib-1.0 libsodium) \
    -I. -Wno-incompatible-pointer-types -Wno-discarded-qualifiers

# 3. Compile C++ backup manager
g++ -c backup-manager.cpp -o backup-manager-impl.o \
    -std=c++17 \
    $(pkg-config --cflags glib-2.0 gio-unix-2.0 json-glib-1.0 libsodium) \
    -I.

# 4. Link final executable
g++ libdvx3.o backup-manager-impl.o -o cli_backup_manager \
    $(pkg-config --libs glib-2.0 gio-unix-2.0 json-glib-1.0 libsodium) \
    -lsodium -lpthread -ldl

# Clean temporary files
rm -f libdvx3.o backup-manager-impl.o
```

---

## Building the GUI Application

### GTK4 Build

```bash
cd /home/dvx3/Documenti/Programming/Vala/Dvx3-Backup-Manager

# Create output directory
mkdir -p build-gui

# Build all Vala source files
valac \
    gui/src/dashboard.vala \
    libdvx3.vala \
    -H dvx3.h \
    $(pkg-config --cflags gtk+-4.0 gio json-glib-1.0 libsodium) \
    $(pkg-config --libs gtk+-4.0 gio json-glib-1.0 libsodium) \
    -o build-gui/dvx3-backup-manager

# Run the application
./build-gui/dvx3-backup-manager
```

### Using Gtk.Builder UI Files

If you have `.ui` files:

```bash
valac \
    gui/src/*.vala \
    $(pkg-config --cflags gtk+-4.0 gio json-glib-1.0 libsodium) \
    $(pkg-config --libs gtk+-4.0 gio json-glib-1.0 libsodium) \
    -o build-gui/dvx3-backup-manager

# Add resources if needed
cp gui/resources/* build-gui/ 2>/dev/null || true
```

---

## Building for macOS

### Requirements

```bash
# Install macOS dependencies (via Homebrew)
brew install valac gcc libsodium gtk4

# Set environment variables
export DYLD_LIBRARY_PATH=/usr/local/lib:$DYLD_LIBRARY_PATH

# Build with macOS flags
valac \
    gui/src/*.vala \
    libdvx3.vala \
    -H dvx3.h \
    $(pkg-config --cflags gtk+-4.0 gio json-glib-1.0 libsodium) \
    $(pkg-config --libs gtk+-4.0 gio json-glib-1.0 libsodium) \
    -framework Cocoa \
    -framework AppKit \
    -o dvx3-backup-manager-macos

# Create app bundle
mkdir -p Dvx3\ Backup\ Manager.app/Contents/MacOS
cp dvx3-backup-manager-macos Dvx3\ Backup\ Manager.app/Contents/MacOS/Dvx3BackupManager
```

---

## Building for Windows

### Requirements

Install **Visual Studio 2022** with C++ workload or use MinGW-w64.

### Build Script

```bash
cd /home/dvx3/Documenti/Programming/Vala/Dvx3-Backup-Manager

# Generate C sources (Windows compatible)
./gen_c_sources.sh

# Compile with Windows flags
valac \
    gui/src/*.vala \
    libdvx3.vala \
    -H dvx3.h \
    $(pkg-config --cflags gtk+-4.0 gio json-glib-1.0 libsodium) \
    $(pkg-config --libs gtk+-4.0 gio json-glib-1.0 libsodium) \
    -mwindows \
    -o build-gui/dvx3-backup-manager.exe
```

---

## Building for Linux (Recommended)

### Single Executable Build

```bash
cd /home/dvx3/Documenti/Programming/Vala/Dvx3-Backup-Manager

# Generate C sources (optional, for some platforms)
./gen_c_sources.sh || true

# Compile CLI tool directly from Vala source
valac \
    main.vala \
    libdvx3.vala \
    -H dvx3.h \
    $(pkg-config --cflags glib-2.0 gio-unix-2.0 json-glib-1.0 libsodium) \
    $(pkg-config --libs glib-2.0 gio-unix-2.0 json-glib-1.0 libsodium) \
    -lpthread -ldl \
    -o cli_backup_manager

# Compile GUI application (if needed)
valac \
    gui/src/*.vala \
    libdvx3.vala \
    -H dvx3.h \
    $(pkg-config --cflags gtk+-4.0 gio json-glib-1.0 libsodium) \
    $(pkg-config --libs gtk+-4.0 gio json-glib-1.0 libsodium) \
    -lpthread -ldl \
    -o dvx3-backup-manager
```

---

## Testing Your Build

### Run CLI Tool

```bash
./cli_backup_manager

# Should prompt for backup source directory
```

### Run GUI Application

```bash
./dvx3-backup-manager

# Or using GTK4:
GTK_BACKEND=x11 ./dvx3-backup-manager
```

---

## Troubleshooting

### "pkg-config" Not Found

```bash
sudo apt install pkg-config
```

### libsodium Not Found

```bash
# Debian/Ubuntu
sudo apt install libsodium-dev

# Arch Linux
sudo pacman -S libsodium

# Fedora
sudo dnf install development-libsodium
```

### Valac Version Too Old

```bash
# Install latest Vala from PPA (Ubuntu)
sudo add-apt-repository ppa:vala-team/ppa
sudo apt update
sudo apt install valac
```

### GTK Theme Issues

```bash
# Install Nux theme for better appearance
sudo apt install nux-theme
# Or use any GTK4-compatible theme
```

---

## Release Build Process

### Create Release Artifact

```bash
cd /home/dvx3/Documenti/Programming/Vala/Dvx3-Backup-Manager

# Clean previous builds
rm -rf build-release/* 2>/dev/null || mkdir -p build-release

# Create release directory
mkdir -p build-release/cli-linux-x86_64
mkdir -p build-release/gui-linux-x86_64

# Build CLI tool for current platform
./build_backup_manager.sh && \
    mv cli_backup_manager build-release/cli-linux-$(uname -m).tar.gz

# Package with README and LICENSE
cd build-release
tar -czf cli-linux-x86_64.tar.gz \
    cli_backup_manager \
    README.md \
    LICENSE

# Build GUI application (optional)
valac \
    gui/src/*.vala \
    libdvx3.vala \
    -H dvx3.h \
    $(pkg-config --cflags gtk+-4.0 gio json-glib-1.0 libsodium) \
    $(pkg-config --libs gtk+-4.0 gio json-glib-1.0 libsodium) \
    -o gui-linux-x86_64/dvx3-backup-manager

# Package GUI appimage (requires libappimagex)
./build-appimage.sh 2>/dev/null || true
```

### Create GitHub Release

```bash
# Tag the release
git tag -a v1.0.0 -m "Release v1.0.0 with integrity verification"
git push origin --tags

# Create release on GitHub (via CLI)
gh release create v1.0.0 \
    --title "Dvx3 Backup Manager v1.0.0" \
    --notes "$(cat RELEASE_NOTES.md)" \
    build-release/cli-linux-x86_64.tar.gz
```

---

## Continuous Integration (GitHub Actions)

The repository includes a `.github/workflows/build.yml` file with CI configurations for:

- **macOS:** Intel and Apple Silicon
- **Linux:** amd64, arm64  
- **Windows:** x86_64, arm64

### Adding New Platform to CI

Edit `.github/workflows/build.yml`:

```yaml
jobs:
  linux-arm64:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      
      - name: Install dependencies
        run: |
          sudo apt update && sudo apt install -y valac gcc pkg-config libsodium-dev glib2.0-dev json-glib-dev
      
      - name: Build CLI
        run: ./build_backup_manager.sh
      
      - name: Upload artifact
        uses: actions/upload-artifact@v4
        with:
          name: dvx3-linux-arm64
          path: cli_backup_manager
```

---

## Development Environment Setup

### IDE Configuration

**VS Code:**
```json
{
    "vala.executable": "valac",
    "vala.vapidir": "./vala-extra-vapis",
    "vala.pkg": [
        "--pkg=glib-2.0",
        "--pkg=gio-unix-2.0",
        "--pkg=json-glib-1.0",
        "--pkg=posix",
        "--pkg=libsodium"
    ]
}
```

**Eclipse Valang:**
- Install Vala plugin from Eclipse Marketplace
- Set VAPI path: `vala-extra-vapis`
- Add packages: glib, gio, json-glib, libsodium

---

## Performance Optimization

### Static Linking (for distribution)

```bash
# Create statically linked executable
valac \
    main.vala \
    libdvx3.vala \
    -H dvx3.h \
    $(pkg-config --cflags glib-2.0 gio-unix-2.0 json-glib-1.0 libsodium) \
    $(pkg-config --libs glib-2.0 gio-unix-2.0 json-glib-1.0 libsodium) \
    -static \
    -o cli_backup_manager-static

# Or use musl libc for static builds (advanced)
```

### Stripping Binary

```bash
strip --strip-unneeded cli_backup_manager
ls -lh cli_backup_manager
```

---

## Verification Checklist

Before releasing, verify:

- [ ] Build completes without warnings
- [ ] CLI tool creates backup successfully
- [ ] CLI tool decrypts archive correctly
- [ ] Integrity verification works (WITH_INTEGRITY mode)
- [ ] Legacy archives remain readable
- [ ] Progress tracking displays correctly
- [ ] No memory leaks in long-running operations
- [ ] GUI application launches (if applicable)

---

**Last Updated:** 2026-09-13  
**Build System Version:** 1.0  
**Supported Platforms:** Linux, macOS, Windows  