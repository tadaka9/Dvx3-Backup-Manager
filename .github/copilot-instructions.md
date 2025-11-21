# Copilot Instructions for Dvx3 Backup Manager

## Project Overview
- **Dvx3 Backup Manager** is a cross-platform, encrypted, and compressed backup system with CLI, TUI, Qt6 GUI, and C++/Vala/C API interfaces.
- Major components:
  - `dvx3-cli.vala`, `libdvx3.vala`, `dvx3.h`, `dvx3.hpp`: Core encryption/compression logic and APIs
  - `backup-manager`, `backup-manager-gui`: TUI and GUI frontends
  - `build*.sh`: Platform-specific build scripts
  - `vala-extra-vapis/`: Vala bindings for external libs (e.g., libsodium)

## Architecture & Data Flow
- **Backup pipeline:** `tar` (streamed) → `zstd` (compression) → `XSalsa20-Poly1305` (encryption, libsodium)
- **No intermediate files:** All operations are streaming for efficiency
- **Job management:** Configs and history in `~/.config/backup-manager/`
- **Archive format:** Custom, with JSON header and chunked encrypted data (see README)

## Developer Workflows
- **Build all (CLI, GUI, library):** `./build-all.sh`
- **Build GUI only:** `./build_gui.sh`
- **Build C++ example:** `./gen_c_sources.sh && ./build_cpp.sh`
- **Run TUI:** `./backup-manager`
- **Run GUI:** `./backup-manager-gui`
- **CLI usage:** `./dvx3 encrypt ...` and `./dvx3 decrypt ...`
- **Install:** `sudo ./install.sh` (system) or `PREFIX=~/.local ./install.sh` (user)
- **Config files:** `backup-manager.conf`, `backup-history.log` in config dir

## Project-Specific Conventions
- **Passwords** are stored in plaintext in config files—**set file permissions** (`chmod 600 ...`)
- **Compression:** zstd, configurable level (1-22), multi-threaded
- **Encryption:** Argon2id KDF, XSalsa20-Poly1305 (libsodium)
- **Cross-platform:** Linux, macOS, Windows (cross-compile), Raspberry Pi
- **C++ API:** Modern RAII wrappers in `dvx3.hpp`
- **Vala API:** Use `Dvx3.encrypt()`/`Dvx3.decrypt()`
- **GUI:** Settings and job configs are persisted between sessions

## Integration & Dependencies
- **External:** libsodium, zstd, GLib, JSON-GLib, Qt6
- **Vala extra vapis:** in `vala-extra-vapis/`
- **C++/Vala/C API:** All share the same core logic via generated C code

## Examples
- **C++:** See `example.cpp` and `dvx3.hpp` for usage
- **Vala:** See `libdvx3.vala` and `dvx3-cli.vala`
- **Build scripts:** Use provided `build*.sh` for all platforms

## References
- See `README.md`, `CPP_USAGE.md`, `BUILD_MULTIPLATFORM.md`, `GUI_GUIDE.md`, `SECURITY.md` for details
- For backup job/GUI specifics: `BACKUP_MANAGER_GUIDE.md`, `GUI_GUIDE.md`

---

**When contributing code or using AI agents, follow these conventions and reference the above files for platform, build, and API details.**
