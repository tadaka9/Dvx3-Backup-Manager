# Building Dvx3 Backup Manager

`build.sh` is the canonical native build driver. `make TARGET` and
`scripts/run-tests.sh` delegate to it. Commands may be combined in order;
`all` builds only the current host, never a list of foreign platforms.

## Dependencies

Core: Bash 3.2+, Vala 0.56+, a native C compiler and `ar`, pkg-config,
GLib/GIO >= 2.66, JSON-GLib and libsodium. CLI and manager use the core.
GUI additionally requires a native C++17 compiler, CMake >= 3.21 and Qt >= 6.4.
Runtime: tar plus the executable for the selected codec. No GTK, gio-unix,
MSVC, undocumented Vala `--capi` flag or custom PIC libsodium build is required.

Ubuntu/Debian:

```sh
sudo apt-get install build-essential valac pkg-config cmake qt6-base-dev \
  libglib2.0-dev libjson-glib-dev libsodium-dev zstd gzip bzip2 xz-utils
# Optional codecs and shell checks:
sudo apt-get install lz4 brotli 7zip zpaq shellcheck
```

macOS candidate, with Homebrew and Xcode command-line tools:

```sh
brew install vala pkgconf cmake qt glib json-glib libsodium zstd gzip bzip2 xz \
  lz4 brotli sevenzip zpaq
export CMAKE_PREFIX_PATH="$(brew --prefix qt)"
export PATH="$(brew --prefix gzip)/bin:$(brew --prefix bzip2)/bin:$PATH"
./build.sh all test
```

Windows candidate: run inside **MSYS2 UCRT64**, with native UCRT64 GCC, Vala,
pkgconf, CMake/Ninja, GLib, JSON-GLib, libsodium, Qt6 and desired codecs.
The exact package list is in `.github/workflows/ci.yml`. Use
`CC=gcc CXX=g++ CMAKE_GENERATOR=Ninja ./build.sh all test`.
PowerShell cannot directly execute `build.sh`. MSVC is not a supported toolchain.
Dependencies must remain on PATH at runtime; binaries are development outputs,
not self-contained redistributable packages.

## Targets and outputs

| Target | Result / prerequisites |
| --- | --- |
| `core` | Vala engine and manager service, static/shared lib and generated C header/VAPI |
| `cli` | core + `build/bin/dvx3` |
| `manager` | core + Vala `build/bin/backup-manager` |
| `gui` | core + Qt `build/bin/dvx3-backup-manager` |
| `all` | core, CLI, manager, GUI on the native host |
| `test` | core, CLI, manager, Vala functional tests, C++ binding round trip and CLI smoke tests |
| `clean` | removes only the repository's `build/` tree; needs no development dependencies |

Windows executables have `.exe`. Libraries are in `build/lib/`:
`libdvx3.a` and `.so` (Linux), `.dylib` (macOS), `.dll` plus import library
(Windows). Generated header/VAPI/C live in `build/generated/`, objects in
`build/obj/`, Qt intermediate output in `build/gui/`, tests in `build/tests/`.
CLI/manager/GUI statically link the canonical core, retaining dynamic system
library dependencies. No generated artifact is tracked.

```sh
./build.sh clean all test
./build.sh core cli manager --target=native
./scripts/run-tests.sh
make test
QT_QPA_PLATFORM=offscreen build/bin/dvx3-backup-manager --smoke-test
```

`--target=<os>-<arch>` asserts the native host: e.g. `linux-x86_64`,
`linux-arm64`, `macos-arm64`, `macos-x86_64`, `windows-x86_64`.
OS and architecture come from `uname`; Windows also requires `MSYSTEM=UCRT64`.
Foreign targets and cross-compilation variables are rejected before building.
`CC`, `CXX`, `VALAC`, `PKG_CONFIG`, `JOBS` (default 2), PATH and
`CMAKE_PREFIX_PATH` select installed native tools. Compiler commands are single
executable names/paths, not shell command strings. The C compiler must produce
a runnable native program. Dependency and compiler failures terminate the build.

## Verification status

- **Linux x86_64**: built and tested locally on Pop!_OS 24.04, Vala 0.56.16,
  GCC 13.3, GLib 2.80, JSON-GLib 1.8, libsodium 1.0.18, Qt 6.4.2.
- Linux ARM64: native `ubuntu-24.04-arm` CI job configured; pending actual run.
- macOS ARM64 / Intel: native `macos-15` / `macos-15-intel` candidate jobs;
  pending actual runs.
- Windows x64: native `windows-2022` / MSYS2 UCRT64 candidate job;
  pending actual run. ZPAQ/Razor require separately supplied tools/adapters.
- ARMHF and Windows ARM64: no tested toolchain/runner; **not declared supported**.

Runner labels follow the [GitHub runner reference](https://docs.github.com/en/actions/reference/runners/github-hosted-runners).
The macOS Vala package is [Homebrew `vala`](https://formulae.brew.sh/formula/vala),
not a `valac` cask. Windows uses [MSYS2 UCRT64 Vala](https://packages.msys2.org/packages/mingw-w64-ucrt-x86_64-vala).
No CI job is allowed to fail silently. Configuring a job is not proof of success.

Tests exercise all detected codecs. CI sets `DVX3_REQUIRE_CODECS` to a comma-separated
list so missing required codecs cause failure rather than a skipped test.
`dvx3 --codecs` reports tool/profile availability, which is not a self-test.
See [COMPRESSION.md](COMPRESSION.md) for verified codecs and extension contracts.

No DEB, RPM, AppImage, DMG, MSI or NSIS packaging is implemented or advertised.
`install.sh` is a POSIX development installer, not a package builder.

Vala 0.56.16 emits C qualifier/pointer warnings with GLib 2.80 in this environment;
these are reported and do not hide failed compilations. Newer native toolchains
still need their own CI verification.
