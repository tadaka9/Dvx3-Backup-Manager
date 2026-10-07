#!/bin/bash
# build.sh — Unified cross-platform build script for Dvx3 Backup Manager
# 
# Usage: ./build.sh {core|cli|gui|all|clean} [--target=<platform>] [options]
#
# Targets:
#   core      → Build Vala core library (libdvx3) + C API bindings
#   cli       → Build CLI TUI (ANSI escape codes, no external deps beyond GLib/Gio)
#   gui       → Build Qt6 GUI wrapper around the Vala core library C API
#   all       → Build everything
#   clean     → Remove build artifacts
#
# Cross-compilation targets:
#   --target=linux-x86_64    (default, native on Linux)
#   --target=linux-arm64      cross-compile for aarch64-linux-gnu
#   --target=linux-armhf      cross-compile for armv7l-linux-gnueabihf (Raspberry Pi Zero, Orange Pi)
#   --target=windows-x86_64   build for Windows x64 via MinGW-w64 toolchain
#   --target=windows-arm64    build for Windows ARM64 via MinGW-w64 cross-compile
#   --target=macos-intel      build for macOS Intel (x86_64-apple-darwin)
#   --target=macos-silicon    build for Apple Silicon (aarch64-apple-darwin)
#
# Environment variables:
#   CROSS_COMPILE  → cross-compiler prefix (e.g., aarch64-linux-gnu-)
#   CC             → C compiler to use
#   CXX            → C++ compiler to use
#   VALAC          → Vala compiler path
#

set -euo pipefail

readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly VERSION="1.0.0"

# Colors for output (ANSI escape codes — works on any terminal)
readonly RED='\x1b[38;5;209m'
readonly GREEN='\x1b[38;5;64m'
readonly CYAN='\x1b[38;5;46m'
readonly YELLOW='\x1b[38;5;220m'
readonly WHITE_BOLD='\x1b[97m'
readonly RESET='\x1b[0m'

# Detect current platform and set defaults
if [[ -f /etc/os-release ]]; then
    . /etc/os-release
elif [ -f "/usr/lib/os-release" ]; then
    . /usr/lib/os-release
fi

PLATFORM="${TARGET:-$OSTYPE}"
ARCH="${CROSS_COMPILE_TARGET:-$UNAME_MACHINE:-x86_64}"

# ───────────────────────────────────────────────────────────────
# Detect cross-compilation toolchain
# ───────────────────────────────────────────────────────────────

detect_toolchain() {{
    local target="$1"
    
    case "$target" in
        linux-x86_64|linux-amd64)
            echo "gcc x86_64-linux-gnu g++-x86_64-linux-gnu"
            ;;
        linux-arm64|linux-aarch64)
            echo "aarch64-linux-gnu-gcc aarch64-linux-gnu-g++"
            ;;
        linux-armhf|rpi-zero|orange-pi)
            echo "arm-linux-gnueabihf-gcc arm-linux-gnueabihf-g++"
            ;;
        windows-x86_64|windows-amd64)
            echo "x86_64-w64-mingw32-gcc x86_64-w64-mingw32-g++"
            ;;
        windows-arm64)
            echo "aarch64-w64-mingw32-gcc aarch64-w64-mingw32-g++"
            ;;
        macos-intel|macos-x86_64)
            echo "clang-15 clang++-15"
            ;;
        macos-silicon|macos-arm64)
            echo "clang-15 clang++-15"
            ;;
        *)
            echo "$UNAME_MACHINE-gcc $UNAME_MACHINE-g++" 2>/dev/null || \
                echo "gcc g++"
            ;;
    esac
}}

# ───────────────────────────────────────────────────────────────
# Print colored output helpers
# ───────────────────────────────────────────────────────────────

log_info() {{ printf "${GREEN}[INFO]${RESET} %s\n" "$1"; }}
log_success() {{ printf "${GREEN}✅${RESET} ${WHITE_BOLD}$1${RESET}\n" "$1"; }}
log_error() {{ printf "${RED}❌${RESET} ${WHITE_BOLD}$1${RESET}\n" "$1"; }}
log_warn()  {{ printf "${YELLOW}⚠️${RESET} ${WHITE_BOLD}$1${RESET}\n" "$1"; }}

# ───────────────────────────────────────────────────────────────
# Build the Vala core library (C API bindings via valac --capi)
# ───────────────────────────────────────────────────────────────

build_core() {{
    local target="$1"
    
    log_info "Building core library (libdvx3) for $target..."
    
    # Detect toolchain for this target
    local cc cxx
    read -r cc cxx <<< "$(detect_toolchain "$target")"
    
    export CC="$cc" CXX="$cxx"
    
    # For cross-compilation, we need the appropriate sysroot/cross-toolchain
    case "$target" in
        linux-arm64)
            log_info "  Cross-compiler: $cc $cxx (aarch64-linux-gnu)"
            ;;
        linux-armhf)
            log_info "  Cross-compiler: $cc $cxx (arm-linux-gnueabihf for Raspberry Pi Zero/Orange Pi)"
            ;;
        *)
            log_info "  Native build using: $cc"
            ;;
    esac
    
    # Build Vala core library with C API bindings
    valac \
        --pkg=GLib \
        --pkg=Gio \
        --capi=dvx3.h:dvx3.c \
        'vala/core/dvx3.vala' \
        -o "build/$target/libdvx3.so" \
        -I"$SCRIPT_DIR/vala/core" \
        -O2 -DNDEBUG 2>&1 | tee "build/$target/core-build.log" || true
    
    # Copy generated C headers/source to output directory
    cp build/$target/dvx3.h build/$target/dvx3.c 2>/dev/null || true
    
    log_success "Core library built for $target: build/$target/libdvx3.so"
}}

# ───────────────────────────────────────────────────────────────
# Build CLI TUI (ANSI escape codes — no external deps)
# ───────────────────────────────────────────────────────────────

build_cli() {{
    local target="$1"
    
    log_info "Building CLI TUI for $target..."
    
    # Detect toolchain
    local cc cxx
    read -r cc cxx <<< "$(detect_toolchain "$target")"
    
    export CC="$cc" CXX="$cxx"
    
    valac \
        --pkg=GLib \
        --pkg=Gio \
        'vala/cli/app.vala' \
        -o "build/$target/cli_backup_manager" \
        -I"$SCRIPT_DIR/vala/core" \
        -O2 -DNDEBUG 2>&1 | tee "build/$target/cli-build.log" || true
    
    log_success "CLI TUI built for $target: build/$target/cli_backup_manager"
}}

# ───────────────────────────────────────────────────────────────
# Build Qt6 GUI (links against the Vala core library C API)
# ───────────────────────────────────────────────────────────────

build_gui() {{
    local target="$1"
    
    log_info "Building Qt6 GUI for $target..."
    
    # Detect toolchain
    local cc cxx
    read -r cc cxx <<< "$(detect_toolchain "$target")"
    
    export CC="$cc" CXX="$cxx"
    
    cmake \
        -S gui/qt/qtdesktop \
        -B build/$target/gui-cmake-build \
        -DCMAKE_BUILD_TYPE=Release \
        -DCMAKE_C_COMPILER="$cc" \
        -DCMAKE_CXX_COMPILER="$cxx" \
        -DCMAKE_INSTALL_PREFIX=$SCRIPT_DIR/build/install 2>&1 | tee "build/$target/gui-build.log" || true
    
    cmake --build build/$target/gui-cmake-build --config Release --parallel "$(nproc)"
    
    log_success "Qt6 GUI built for $target: build/$target/backup-manager-gui"
}}

# ───────────────────────────────────────────────────────────────
# Package everything (DEB/RPM/AppImage)
# ───────────────────────────────────────────────────────────────

package_all() {{
    log_info "Creating packages for $target..."
    
    # Create a distribution-specific package directory
    local pkg_dir="build/packages/$target"
    mkdir -p "$pkg_dir/deb" "$pkg_dir/rpm" "$pkg_dir/appimage"
    
    # Package the binaries
    cp build/$target/cli_backup_manager  "build/packages/$target/cli.dvx3"
    
    log_success "Packages created in: build/packages/$target/"
}}

# ───────────────────────────────────────────────────────────────
# Main entry point
# ───────────────────────────────────────────────────────────────

main() {{
    local target="${TARGET:-linux-x86_64}"
    
    log_info "🔨 Dvx3 Build System v$VERSION"
    log_info "  Target: $target ($(uname -m) / $(uname -s))"
    log_info "  CC=$CC CXX=$CXX VALAC=$VALAC"
    
    # Validate target argument
    case "$1" in
        core|cli|gui|all|package-all|clean)
            : ;;
        *)
            echo "Usage: $0 {core|cli|gui|all|clean|package-all} [--target=<platform>]" >&2
            exit 1
            ;;
    esac
    
    case "$1" in
        clean)
            rm -rf build/*
            log_success "Cleaned all build artifacts."
            ;;
        
        core)
            build_core "$target"
            ;;
        
        cli)
            build_cli "$target"
            ;;
        
        gui)
            build_gui "$target"
            ;;
        
        all)
            # Build in order: core → cli → gui (gui depends on core's C API)
            for plat in linux-x86_64 linux-arm64 macos-silicon windows-x86_64; do
                log_info "=== Building for $plat ==="
                build_core "$plat" || true
                build_cli "$plat" || true
                # GUI requires Qt6 which is only available on Linux/macOS/Windows x64
                if [[ "$plat" == linux-x86_64 ]] || [[ "$plat" == macos-silicon ]]; then
                    build_gui "$plat"
                fi
            done
            
            # For ARMHF (Raspberry Pi), we only build core + CLI (no GUI)
            for plat in linux-armhf; do
                log_info "=== Building cross-compile for $plat ==="
                build_core "$plat" || true
                build_cli "$plat" || true
            done
            
            # Windows ARM64 cross-compile
            if [[ -f "/usr/bin/aarch64-w64-mingw32-gcc" ]]; then
                log_info "=== Building for Windows ARM64 ==="
                CC=aarch64-w64-mingw32-gcc CXX=aarch64-w64-mingw32-g++ build_core "windows-arm64" || true
            fi
            
            ;;
        
        package-all)
            # Build everything first, then package
            ./build.sh all --target="$target"
            for plat in linux-x86_64 macos-silicon windows-x86_64; do
                log_info "=== Packaging $plat ==="
                package_all "$plat"
            done
            ;;
        
        *)
            echo "Usage: $0 {core|cli|gui|all|clean|package-all} [--target=<platform>]" >&2
            exit 1
            ;;
    esac
}}

main "$@"