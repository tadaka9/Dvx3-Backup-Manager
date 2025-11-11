#!/bin/bash
# Build script for dvx3 library and CLI (cross-platform)

set -e

VAPIDIR="vala-extra-vapis"

# Detect platform
UNAME_OUT="$(uname -s 2>/dev/null || echo unknown)"
case "$UNAME_OUT" in
    MINGW*|MSYS*|CYGWIN*)
        PLATFORM=os_windows
        GIO_PKG="gio-2.0"
        ;;
    *)
        PLATFORM=os_unix
        GIO_PKG="gio-2.0 --pkg gio-unix-2.0"
        ;;
esac

PACKAGES="--pkg glib-2.0 --pkg $GIO_PKG --pkg json-glib-1.0 --pkg posix --pkg libsodium"

case "$PLATFORM" in
    os_windows)
        SHARED_EXT="dll"
        LIB_OUT="libdvx3.$SHARED_EXT"
        PIC_FLAG=""
        SHARED_LINK_FLAGS=(-X -shared -X -Wl,--out-implib,libdvx3.dll.a -X -Wl,--export-all-symbols)
        RPATH_FLAG=()
        EXE_EXT=".exe"
        VALA_DEFINES="-D WINDOWS"
        ;;
    os_macos)
        SHARED_EXT="dylib"
        LIB_OUT="libdvx3.$SHARED_EXT"
        PIC_FLAG="-X -fPIC"
        SHARED_LINK_FLAGS=(-X -dynamiclib)
        # Use @loader_path so CLI finds library in same directory
        RPATH_FLAG=(-X -Wl,-rpath,@loader_path)
        EXE_EXT=""
        VALA_DEFINES=""
        ;;
    os_unix)
        SHARED_EXT="so"
        LIB_OUT="libdvx3.$SHARED_EXT"
        PIC_FLAG="-X -fPIC"
        SHARED_LINK_FLAGS=(-X -shared)
        RPATH_FLAG=(-X -Wl,-rpath,'$ORIGIN')
        EXE_EXT=""
        VALA_DEFINES=""
        ;;
esac

echo "Building libdvx3 ($LIB_OUT)..."

# Build shared library
valac --vapidir="$VAPIDIR" $PACKAGES \
        $VALA_DEFINES \
        --library=dvx3 \
        --vapi=dvx3.vapi \
        --header=dvx3.h \
        $PIC_FLAG \
        "${SHARED_LINK_FLAGS[@]}" \
        -o "$LIB_OUT" \
        libdvx3.vala

echo "Building dvx3 CLI..."

# Build CLI executable
valac --vapidir="$VAPIDIR" $PACKAGES \
        --pkg dvx3 \
        --vapidir=. \
        -X -I. \
        -X -L. \
        -X -ldvx3 \
        ${RPATH_FLAG[@]} \
        -o "dvx3$EXE_EXT" \
        dvx3-cli.vala

echo "✅ Build complete!"
echo ""
echo "Files created:"
echo "  - $LIB_OUT        (shared library)"
echo "  - dvx3.vapi       (Vala API)"
echo "  - dvx3.h          (C header)"
echo "  - dvx3$EXE_EXT    (CLI executable)"
echo ""
echo "Usage:"
case "$PLATFORM" in
    os_windows)
        echo "  ./dvx3.exe encrypt <folder> -p <password> -o <output.dvx3>" ;;
    *)
        echo "  ./dvx3 encrypt <folder> -p <password> -o <output.dvx3>" ;;
esac
case "$PLATFORM" in
    os_windows)
        echo "  ./dvx3.exe decrypt <archive.dvx3> -p <password> -o <output_dir>" ;;
    *)
        echo "  ./dvx3 decrypt <archive.dvx3> -p <password> -o <output_dir>" ;;
esac
