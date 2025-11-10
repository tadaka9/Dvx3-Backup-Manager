# C++ Usage Guide for dvx3

## Overview

The Vala library has been successfully transpiled to C and wrapped with modern C++ interfaces. You can now use the dvx3 encryption library from C++ with RAII wrappers.

## Generated Files

- `gen-c/libdvx3.c` - Generated C source from Vala
- `dvx3.h` - C header file (auto-generated)
- `dvx3.hpp` - Modern C++ wrapper with RAII
- `example.cpp` - Complete C++ example
- `dvx3-cpp` - Compiled C++ executable

## Building from C++

### Quick Build

```bash
./gen_c_sources.sh   # Generate C sources from Vala
./build_cpp.sh       # Build C++ example
```

### Manual Build

```bash
# Generate C sources
valac --vapidir=vala-extra-vapis --pkg glib-2.0 --pkg gio-unix-2.0 \
  --pkg json-glib-1.0 --pkg posix --pkg libsodium \
  --ccode --directory=gen-c --library=dvx3 \
  --vapi=dvx3.vapi --header=dvx3.h libdvx3.vala

# Compile C code
gcc -c gen-c/libdvx3.c -o libdvx3.o -fPIC -I. \
  $(pkg-config --cflags glib-2.0 gio-2.0 gio-unix-2.0 json-glib-1.0 libsodium)

# Compile C++ wrapper
g++ -c example.cpp -o example.o -std=c++17 -I. \
  $(pkg-config --cflags glib-2.0 gio-2.0)

# Link
g++ example.o libdvx3.o -o dvx3-cpp \
  $(pkg-config --libs glib-2.0 gio-2.0 gio-unix-2.0 json-glib-1.0 libsodium)
```

## C++ API Usage

### Simple Example

```cpp
#include "dvx3.hpp"
#include <iostream>

int main() {
    try {
        // Encrypt
        dvx3::encrypt(
            "/path/to/folder",      // source directory
            "backup.dvx3",          // output file
            "my-password"           // password
        );
        
        // Decrypt
        dvx3::decrypt(
            "backup.dvx3",          // encrypted file
            "/restore/to",          // output directory
            "my-password"           // password
        );
        
        std::cout << "Success!\n";
    } catch (const dvx3::Exception& e) {
        std::cerr << "Error: " << e.what() << "\n";
        return 1;
    }
    return 0;
}
```

### With Progress Tracking

```cpp
#include "dvx3.hpp"
#include <iostream>

int main() {
    try {
        dvx3::encrypt(
            "/path/to/folder",
            "backup.dvx3",
            "password",
            "",  // no exclude path
            [](uint64_t processed, uint64_t total, uint64_t output) {
                double pct = (double)processed / total * 100.0;
                std::cout << "Progress: " << pct << "% | "
                         << dvx3::format_size(processed) << " -> "
                         << dvx3::format_size(output) << "\r";
                std::cout.flush();
            }
        );
        std::cout << "\nDone!\n";
    } catch (const dvx3::Exception& e) {
        std::cerr << "Error: " << e.what() << "\n";
        return 1;
    }
    return 0;
}
```

## C++ Features

- **RAII**: `dvx3::File` automatically manages GFile* lifetime
- **Exceptions**: Errors are thrown as `dvx3::Exception`
- **Lambdas**: Progress callbacks use `std::function`
- **Modern C++17**: Uses features like structured bindings where beneficial

## Command-Line Tool

The compiled `dvx3-cpp` executable works like the Vala version:

```bash
# Encrypt
./dvx3-cpp encrypt ./my_folder backup.dvx3 "password"

# Decrypt
./dvx3-cpp decrypt backup.dvx3 ./restored "password"
```

## Dependencies

- GLib 2.0
- GIO (including gio-unix-2.0)
- JSON-GLib 1.0
- libsodium
- tar (command-line tool)
- zstd (command-line tool)
- C++17 compatible compiler (g++ 7+, clang++ 5+)

## Integration in Your Project

### CMakeLists.txt Example

```cmake
cmake_minimum_required(VERSION 3.10)
project(MyProject)

set(CMAKE_CXX_STANDARD 17)

# Find packages
find_package(PkgConfig REQUIRED)
pkg_check_modules(GLIB REQUIRED glib-2.0 gio-2.0 gio-unix-2.0 json-glib-1.0)
pkg_check_modules(SODIUM REQUIRED libsodium)

# Add dvx3 sources
add_library(dvx3 STATIC gen-c/libdvx3.c)
target_include_directories(dvx3 PUBLIC ${CMAKE_CURRENT_SOURCE_DIR} ${GLIB_INCLUDE_DIRS} ${SODIUM_INCLUDE_DIRS})
target_link_libraries(dvx3 ${GLIB_LIBRARIES} ${SODIUM_LIBRARIES})

# Your application
add_executable(myapp main.cpp)
target_link_libraries(myapp dvx3)
```

### Makefile Example

```makefile
CXX = g++
CC = gcc
CXXFLAGS = -std=c++17 -I. $(shell pkg-config --cflags glib-2.0 gio-2.0)
CFLAGS = -fPIC -I. $(shell pkg-config --cflags glib-2.0 gio-2.0 gio-unix-2.0 json-glib-1.0 libsodium)
LDFLAGS = $(shell pkg-config --libs glib-2.0 gio-2.0 gio-unix-2.0 json-glib-1.0 libsodium)

myapp: main.o libdvx3.o
	$(CXX) $^ -o $@ $(LDFLAGS)

libdvx3.o: gen-c/libdvx3.c
	$(CC) -c $< -o $@ $(CFLAGS)

main.o: main.cpp dvx3.hpp
	$(CXX) -c $< -o $@ $(CXXFLAGS)

clean:
	rm -f *.o myapp
```

## Notes

- The C source is generated from Vala and should not be hand-edited
- The C++ wrapper (`dvx3.hpp`) is header-only for easy integration
- GLib/GIO memory management is handled automatically by RAII wrappers
- The library is thread-safe for independent encrypt/decrypt operations

## Troubleshooting

**Build fails with "dvx3.h not found"**: Run `./gen_c_sources.sh` first

**Linking errors**: Ensure all pkg-config packages are installed:
```bash
pkg-config --modversion glib-2.0 gio-2.0 json-glib-1.0 libsodium
```

**Runtime tar/zstd errors**: Ensure `tar` and `zstd` are in PATH
