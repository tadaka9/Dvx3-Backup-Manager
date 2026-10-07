# Changelog

All notable changes to Dvx3 Backup Manager will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added
- Cross-platform build system using `meson.build` with unified CMake/Ninja backend
- Vala core library (`vala/core/dvx3.vala`) exposed as a shared/static library via `valac --capi`
- CLI TUI implemented in pure Vala (no libtinfo/curses dependency) using ANSI escape codes for cross-platform terminal rendering
- Qt6 GUI now links against the Vala core library's C API instead of reimplementing logic
- Cross-compilation support: Linux ARM64 (Raspberry Pi), Windows ARM64 (via MinGW-w64), macOS Intel/Silicon
- Packaging: DEB, RPM, AppImage for Linux; DMG for macOS; MSI/NSIS for Windows

### Changed
- Refactored architecture to be Vala-centric with a thin Qt6 GUI wrapper
- Core encryption/compression logic moved from C++ into Vala (uses only GObject/GI bindings — no GTK dependencies)
- Replaced platform-specific terminal rendering in CLI TUI: now uses ANSI escape codes instead of libtinfo, making it portable across Linux, Windows Terminal 10+, and macOS iTerm2

### Fixed
- Qt6 GUI compilation errors fixed (lambda capture defaults, duplicate method declarations, `QRandomGenerator::systemRandom()` replaced with `QRNG.global()` fallback)
- Cross-compilation matrix in CI now builds for all supported platforms including ARMHF (Raspberry Pi Zero/Orange Pi)
- `.gitignore` updated to exclude large Vala intermediate files and cross-compilation toolchains

### Deprecated
- The C++ implementation (`backup-manager.cpp`) is retained as a compatibility layer but marked for deprecation. Migration path: link against `libdvx3.so` generated from the Vala core library.

## [1.0.0] — 2025-01-XX

### Added
- Initial release of Dvx3 Backup Manager
- Core encryption pipeline using Argon2id + XSalsa20-Poly1305
- CLI tool with interactive TUI mode
- Qt6 desktop GUI application
- Cross-platform packaging (DEB/RPM/AppImage for Linux, DMG for macOS)

### Security
- All backups are encrypted on-the-fly using AES-GCM-256 or XSalsa20-Poly1305-AEAD
- No plaintext intermediate files — streaming pipeline: `tar → zstd → encrypt` in a single pass
- Key derivation uses Argon2id (memory-hard, adaptive to hardware)

### Performance
- ZSTD compression with configurable levels (default: 9, balance of speed and ratio)
- Multi-threaded parallel chunking during backup operations
- Stream-based I/O minimizes memory footprint even on large datasets

## [0.9.2] — 2025-01-XX

### Fixed
- Fixed nonce reuse bug in stream cipher mode (CVE-style fix: each archive now uses a fresh random nonce)
- Improved password strength estimation to better approximate Shannon entropy

### Changed
- Updated CI matrix to include ARMHF cross-compilation targets for Raspberry Pi Zero / Orange Pi devices

## [0.9.1] — 2025-01-XX

### Fixed
- Fixed a memory leak in the chunk encoder's buffer management (Vala-side fix)
- Corrected type mismatches in the C++ Qt GUI bindings that caused compilation errors on Qt6 6.8+

## [0.9.0] — 2025-01-XX

### Added
- macOS support (Intel and Apple Silicon builds via native toolchains)
- Windows ARM64 cross-compilation via MinGW-w64 toolchain
- AppImage packaging for Linux

---

> **Note:** Version numbers follow semantic versioning. Breaking changes are prefixed with `BREAKING:` in the changelog above.

For more details about architecture decisions, see [ARCHITECTURE.md](ARCHITECTURE.md).
