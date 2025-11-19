#!/bin/bash
set -e

echo "=== Building Dvx3 Backup Manager for all platforms ==="
echo ""

VERSION="0.0.3-alpha111725"
BUILD_COUNT=0

# 1. Build for current platform (always)
echo "▶ Building for current platform..."
./build_gui.sh
if [[ ! -x backup-manager-gui ]]; then
    echo "❌ ERROR: backup-manager-gui was not produced by build_gui.sh!"
    echo "Current directory: $(pwd)"
    echo "Directory contents after build_gui.sh:"
    ls -l
    exit 1
fi
((BUILD_COUNT++))
echo ""

# 2. Linux AppImage (if on x86_64 Linux, not Windows)
if [[ "$(uname -s)" == "Linux" ]] && [[ "$(uname -m)" == "x86_64" ]] && [[ -z "$MSYSTEM" ]]; then
    echo "▶ Building Linux AppImage..."
    if ./build-appimage.sh 2>&1 | tail -5; then
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
    if ./build-raspberry.sh 2>&1 | tail -5; then
        ((BUILD_COUNT++))
    else
        echo "⚠ Raspberry Pi build failed"
    fi
    echo ""
fi

# 4. macOS (only on macOS)
if [[ "$OSTYPE" == "darwin"* ]]; then
    echo "▶ Building for macOS..."
    if [ -f build-macos.sh ] && ./build-macos.sh 2>&1 | tail -5; then
        ((BUILD_COUNT++))
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
