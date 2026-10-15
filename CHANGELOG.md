# Changelog

All notable changes to DVX3 Backup Manager will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added
- Full Vala 0.56 compatibility fixes (hex literals, array initializers, GLib.Bytes API)
- SHA-256 and MD5 implemented in pure Vala with OpenSSL fallback
- PBKDF2-HMAC-SHA256 key derivation for AES-CBC encryption
- Content-addressable storage layout with integrity verification
- Parallel backup threads with configurable worker count
- Compression support: gzip, bzip2, xz, lz4, zstd, brotli

### Changed
- Core library rewritten from scratch to fix all Valac 0.56 type system incompatibilities

## [v2.0.0-beta] — 2026-10-15

### Added
- CLI interface (`dvx3-cli`) for command-line backup and restore operations
- GUI TUI terminal user interface (GTK4)
- Secure password-based encryption with PBKDF2 key derivation
- SHA-256 integrity verification on all restored files
- Incremental backup support via content-addressable indexing

### Changed
- Architecture refactored from Qt/Vala to GTK4/Vala for better Vala 0.56 compatibility
- All cryptographic operations implemented in pure Vala (no external crypto libraries required)

## [v1.0.0] — Initial Release

### Added
- Basic backup and restore functionality
- Qt-based GUI interface
- File system monitoring for incremental backups

[Unreleased]: https://github.com/tadaka9/Dvx3-Backup-Manager/compare/v2.0.0-beta...HEAD
[v2.0.0-beta]: https://github.com/tadaka9/Dvx3-Backup-Manager/releases/tag/v2.0.0-beta