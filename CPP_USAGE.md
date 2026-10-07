# C and C++ interoperability

`./build.sh core` generates `build/generated/dvx3.h` and `dvx3.vapi` from the
canonical Vala sources. Include those generated bindings, never a stale root header.
The core static/shared libraries are under `build/lib/`. `dvx3.hpp` is a RAII/error
wrapper; no C++ manager implementation remains.

Linux/macOS native example (dependencies must be installed):

```sh
c++ -std=c++17 -I. -Ibuild/generated example.cpp build/lib/libdvx3.a \
  $(pkg-config --cflags --libs glib-2.0 gio-2.0 json-glib-1.0 libsodium) \
  -o build/bin/example
build/bin/example encrypt ./data ./data.dvx3 'password'
build/bin/example decrypt ./data.dvx3 ./empty-restore 'password'
```

`dvx3::encrypt(source, archive, password, exclusion, progress, codec)` defaults to
zstd. `dvx3::decrypt(archive, empty_destination, password, progress)` selects the
recorded codec. Errors throw `dvx3::Exception`. Progress callbacks execute on the
calling thread and must not throw across the C ABI; Qt marshals updates via signals.

The generated C API also exposes `Dvx3BackupManager` and codec enumeration/availability.
Use GLib reference counting and free returned GLib strings/arrays appropriately.
Run `./build.sh test` for a byte-exact C++ binding round trip and Vala engine tests.
