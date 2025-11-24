#!/bin/bash
# Build C++ example using generated C sources from Vala
set -e

echo "Building C++ example..."

# Run patched on checked-in gen-c/libdvx3.c if present
if [ -f "gen-c/libdvx3.c" ]; then
    chmod +x scripts/patch-gen-c.sh || true
    scripts/patch-gen-c.sh gen-c/libdvx3.c || true
fi

# Compile generated C library source AS C (not C++)
gcc -c gen-c/libdvx3.c -o libdvx3.o \
    -fPIC \
    -I. \
    $(pkg-config --cflags glib-2.0 gio-2.0 gio-unix-2.0 json-glib-1.0 libsodium)
    -Wno-incompatible-pointer-types -Wno-discarded-qualifiers

# Compile C++ example
g++ -c example.cpp -o example.o \
    -std=c++17 \
    -I. \
    $(pkg-config --cflags glib-2.0 gio-2.0)

# Link everything
SODIUM_STATIC_LINK=""
if [ "${FORCE_STATIC_LIBSODIUM:-0}" -eq 1 ]; then
    if [ -f /usr/lib/libsodium.a ] || [ -f /usr/lib/x86_64-linux-gnu/libsodium.a ] || [ -f /usr/local/lib/libsodium.a ]; then
        echo "FORCE_STATIC_LIBSODIUM=1: Linking libsodium statically into dvx3-cpp"
        SODIUM_STATIC_LINK='-Wl,-Bstatic -lsodium -Wl,-Bdynamic'
    else
        echo "FORCE_STATIC_LIBSODIUM=1 requested, but static libsodium (.a) not found. Aborting." >&2
        exit 1
    fi
else
    if [ -f /usr/lib/libsodium.a ] || [ -f /usr/lib/x86_64-linux-gnu/libsodium.a ] || [ -f /usr/local/lib/libsodium.a ]; then
        echo "Static libsodium found: linking statically into dvx3-cpp"
        SODIUM_STATIC_LINK='-Wl,-Bstatic -lsodium -Wl,-Bdynamic'
    else
        SODIUM_STATIC_LINK=$(pkg-config --libs libsodium || echo "-lsodium")
    fi
fi

g++ example.o libdvx3.o -o dvx3-cpp \
    $(pkg-config --libs glib-2.0 gio-2.0 gio-unix-2.0 json-glib-1.0) $SODIUM_STATIC_LINK

echo "✅ Build complete: ./dvx3-cpp"
echo ""
echo "Usage:"
echo "  ./dvx3-cpp encrypt <folder> <output.dvx3> <password>"
echo "  ./dvx3-cpp decrypt <archive.dvx3> <output_dir> <password>"
