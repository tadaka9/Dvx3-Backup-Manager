#!/bin/bash
# Build C++ example using generated C sources from Vala
set -e

echo "Building C++ example..."

# Compile generated C library source AS C (not C++)
gcc -c gen-c/libdvx3.c -o libdvx3.o \
    -fPIC \
    -I. \
    $(pkg-config --cflags glib-2.0 gio-2.0 gio-unix-2.0 json-glib-1.0 libsodium)

# Compile C++ example
g++ -c example.cpp -o example.o \
    -std=c++17 \
    -I. \
    $(pkg-config --cflags glib-2.0 gio-2.0)

# Link everything
g++ example.o libdvx3.o -o dvx3-cpp \
    $(pkg-config --libs glib-2.0 gio-2.0 gio-unix-2.0 json-glib-1.0 libsodium)

echo "✅ Build complete: ./dvx3-cpp"
echo ""
echo "Usage:"
echo "  ./dvx3-cpp encrypt <folder> <output.dvx3> <password>"
echo "  ./dvx3-cpp decrypt <archive.dvx3> <output_dir> <password>"
