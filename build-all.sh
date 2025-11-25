#!/bin/bash
set -ex

echo "=== Building Dvx3 Backup Manager for all platforms ==="
echo ""

VERSION="0.0.3-alpha111725"
BUILD_COUNT=0

# 1. Build for current platform (always)
echo "▶ Building for current platform..."
./build_gui.sh
chmod +x backup-manager-gui || true
echo "Checking backup-manager-gui presence and permissions:"
ls -l backup-manager-gui || echo "backup-manager-gui not found in current directory!"
file backup-manager-gui || echo "Cannot stat backup-manager-gui!"
if [[ ! -f backup-manager-gui ]]; then
    echo "❌ ERROR: backup-manager-gui was not produced by build_gui.sh!"
    echo "Current directory: $(pwd)"
    echo "Directory contents after build_gui.sh:"
    ls -l
    exit 1
elif [[ ! -x backup-manager-gui ]]; then
    echo "❌ ERROR: backup-manager-gui exists but is not executable!"
    chmod +x backup-manager-gui || true
    if [[ ! -x backup-manager-gui ]]; then
        echo "Failed to make backup-manager-gui executable."
        exit 1
    fi
fi
((BUILD_COUNT++))
echo ""

# 2. Linux AppImage (if on x86_64 Linux, not Windows)
if [[ "$(uname -s)" == "Linux" ]] && [[ "$(uname -m)" == "x86_64" ]] && [[ -z "$MSYSTEM" ]]; then
    echo "▶ Building Linux AppImage..."
    ./build-appimage.sh 2>&1 | tail -5
    if [ ${PIPESTATUS[0]} -eq 0 ]; then
        ((BUILD_COUNT++))
    else
        echo "⚠ AppImage build failed"
    fi
    echo ""
else
    echo "Skipping AppImage build (not Linux x86_64 or running under MSYS2/Windows)"
fi

# 3. Raspberry Pi tarball (if on ARM)
if [[ "$(uname -m)" =~ ^arm ]] || [[ "$(uname -m)" == "aarch64" ]]; then
    echo "▶ Building Raspberry Pi package..."
    ./build-raspberry.sh 2>&1 | tail -5
    if [ ${PIPESTATUS[0]} -eq 0 ]; then
        ((BUILD_COUNT++))
    else
        echo "⚠ Raspberry Pi build failed"
    fi
    echo ""
fi

# Create Releases/linux tar if we are on Linux and the packaging script exists
if [[ "$(uname -s)" == "Linux" ]] && [[ -f scripts/package-linux.sh ]]; then
    echo "▶ Packaging Linux binaries into Releases/linux"
    chmod +x scripts/package-linux.sh || true
    ./scripts/package-linux.sh || true
    # Create compressed tarball for Releases/linux
    mkdir -p Releases
    tar -czf Releases/Dvx3-Backup-Manager-Linux.tar.gz -C Releases linux || true
    echo "";
fi

# 4. macOS (only on macOS)
if [[ "$OSTYPE" == "darwin"* ]]; then
    echo "▶ Building for macOS..."
    if [ -f build-macos.sh ]; then
        ./build-macos.sh 2>&1 | tail -5
        if [ ${PIPESTATUS[0]} -eq 0 ]; then
            ((BUILD_COUNT++))
        else
            echo "⚠ macOS build failed"
        fi
    else
        echo "⚠ macOS build not available or failed"
    fi
    echo ""
fi

echo "========================================="
echo "Build Summary ($BUILD_COUNT platforms)"
echo "========================================="
echo ""

 # List all build artifacts (non-fatal)
echo "Build artifacts:"
ls -lh backup-manager-gui 2>/dev/null && echo "  ✓ backup-manager-gui ($(du -h backup-manager-gui | cut -f1))" || true
ls -lh *.AppImage 2>/dev/null | awk '{print "  ✓ " $9 " (" $5 ")"}' || true
ls -lh *.tar.gz 2>/dev/null | awk '{print "  ✓ " $9 " (" $5 ")"}' || true
ls -lh *.dmg 2>/dev/null | awk '{print "  ✓ " $9 " (" $5 ")"}' || true
ls -lh *.exe 2>/dev/null | awk '{print "  ✓ " $9 " (" $5 ")"}' || true

echo ""
echo "Current platform: $(uname -s) $(uname -m)"
echo ""
echo "Cross-platform builds:"
echo "  Windows: See BUILD_MULTIPLATFORM.md for cross-compile instructions"
echo "  macOS:   Build natively on macOS or use GitHub Actions"
echo ""
exit 0