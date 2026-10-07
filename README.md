<div align="center">

# 🔐 Dvx3 Backup Manager

> **Encrypted, compressed, cross-platform backup system** — CLI • GUI (Qt6) • C++/Vala/C API • Multi-platform packaging

---

[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)
[![Latest Release](https://img.shields.io/badge/release-latest-brightgreen.svg)](https://github.com/tadaka9/Dvx3-Backup-Manager/releases/latest)
[![Platforms](https://img.shields.io/badge/platforms-Linux%20|%20Windows%20|%20macOS%20|%20RaspberryPi-blue)](BUILD_MULTIPLATFORM.md)
[![CI Status](https://img.shields.io/badge/CI-Matrix%20Builds-success.svg?style=for-the-badge&logo=github-actions)](.github/workflows/ci.yml)
[![Vala Language](https://img.shields.io/badge/language-Vala-purple.svg?style=flat&logo=vala)](https://vala.dev/)
[![Security: Argon2id+XSalsa20](https://img.shields.io/badge/security-argon2id%2Bxsalsa20--poly1305-brightgreen?style=for-the-badge&logo=yubico)](SECURITY.md)
[![Matrix Builds](https://img.shields.io/badge/matrix-Linux|Windows|macOS%20Intel|Apple%20Silicon-purple?style=for-the-badge)](#-supported-platforms)
[![Qt6 GUI](https://img.shields.io/badge/GUI-Qt6%20Desktop-green?style=flat&logo=qt)](GUI_GUIDE.md)
[![Argon2 Benchmark](https://img.shields.io/badge/argon2id-iterations%3D8-ff4500?style=for-the-badge&logo=infini-trend)](SECURITY.md#argon2id-key-derivation)
[![zstd Compression](https://img.shields.io/badge/zstd-level--19-faa625?style=for-the-badge&logo=facebook)](#compression-zstd)

---

</div>

## 🚀 Quick Start

```bash
# Clone and build everything
git clone https://github.com/tadaka9/Dvx3-Backup-Manager.git
cd Dvx3-Backup-Manager
./build.sh all
sudo ./install.sh

# Use the CLI
dvx3 encrypt /home/user/documents -p "mysecretpassword" -o backup.dvx3
dvx3 decrypt backup.dvx3 -p "mysecretpassword" -o /restore

# Or use the interactive manager
./backup-manager
```

---

## 🌍 Supported Platforms

| Platform | Architecture | Status | Notes |
|----------|-------------|--------|-------|
| **Linux** | x86_64, ARM64 (Raspberry Pi) | ✅ Native build + DEB/RPM/AppImage | Ubuntu 20.04+, Debian 11+, Fedora 38+ |
| **Windows** | x64 (MSVC) | ✅ Build & run natively | Windows 10/11, MSVC toolchain |
| **Windows** | ARM64 (cross-compile from x64) | ✅ Cross-compiled via MinGW-w64 | WSL2 ARM support available |
| **macOS Intel** | x86_64 | ✅ Native build + DMG | macOS 10.15+ (Catalina+) |
| **macOS Silicon** | Apple M1/M2/M3 (ARM64) | ✅ Native build via `macos-15` runner | Apple Silicon native |

> 💡 All builds are validated in GitHub Actions CI with matrix strategy across platforms.

---

## ✨ Features

### 🔒 Security-First Design

- **Argon2id** key derivation (64 MiB, 3 iterations, adaptive memory)
- **XSalsa20-Poly1305** authenticated encryption (256-bit keys, 192-bit nonces)
- **No plaintext intermediate files** — streaming pipeline: `tar → zstd → encrypt`
- **File permission-aware**: respects source file modes in archives
- **Password hashing**: PBKDF2-HMAC-SHA256 for config encryption (optional)

### ⚡ Performance

- **Multi-threaded zstd compression** (configurable level 1–22)
- **Stream-based I/O** — minimal memory footprint even on large datasets
- **Parallel chunking**: divides source into N parallel streams (default: CPU cores)
- **Progress tracking** with dynamic estimation and ETA

### 🖥️ Multiple Interfaces

| Interface | Description | Command |
|-----------|-------------|---------|
| **CLI** | Full-featured command-line tool | `dvx3` / `backup-manager` |
| **Qt6 GUI** | Modern desktop application with drag-and-drop | `./backup-manager-gui` |
| **C++/Vala API** | Embeddable library for custom integrations | — |

### 📦 Packaging & Distribution

- **DEB/RPM/Flatpak/AppImage/Snap/Flatpak-ready** packages (Linux)
- **DMG installers** (macOS Intel + Silicon)
- **MSI / NSIS / App Installer** (Windows x64, with ARM cross-compilation support in CI)
- **Source tarballs** for every platform combination

---

## 📖 Table of Contents

<!-- TOC starts here -->

- [Quick Start](#quick-start)
- [Features](#features)
- [Supported Platforms](#supported-platforms)
- [Installation](#installation)
  - [System-wide (DEB/RPM/AppImage)](#system-wide-debrpmappimage)
  - [Standalone Binary](#standalone-binary)
  - [From Source](#from-source)
  - [macOS Intel/Silicon](#macos-intelsilicon)
  - [Windows x64 / ARM64](#windows-x64--arm64)
- [Building from Source](#building-from-source)
  - [Prerequisites](#prerequisites)
  - [Linux Build](#linux-build)
  - [macOS Build](#macos-build)
  - [Windows Build](#windows-build)
  - [Cross-compilation Matrix in CI](#cross-compilation-matrix-in-ci)
- [CLI Usage Reference](#cli-usage-reference)
  - [Core Commands](#core-commands)
  - [Interactive Mode (TUI)](#interactive-mode-tui)
  - [Non-interactive scripting mode](#non-interactive-scripting-mode)
- [Qt6 GUI](#qt6-gui)
  - [Screenshots](#screenshots)
  - [Features & Shortcuts](#features--shortcuts)
- [C++ / Vala API Usage](#cpp-vala-api-usage)
- [Archive Internals (Format)](#archive-internals-format)
- [Configuration Files](#configuration-files)
- [Security Considerations](#security-considerations)
  - [Password Best Practices](#password-best-practices)
  - [File Permissions](#file-permissions)
  - [Entropy Sources](#entropy-sources)
- [Troubleshooting & FAQ](#troubleshooting--faq)
- [Contributing](#contributing)
  - [Development Workflow](#development-workflow)
  - [Running Tests Locally](#running-tests-locally)
  - [Linting & Code Quality](#linting--code-quality)
- [Changelog / Release Notes](#changelog-release-notes)
- [License](#license)

<!-- TOC ends here -->

---

## Installation

### System-wide (DEB/RPM/AppImage/Snap/Flatpak)

```bash
# Debian-based systems
sudo apt install ./Dvx3-BackupManager_1.0.0_amd64.deb

# RHEL/Fedora/CentOS
sudo dnf install ./Dvx3-BackupManager-1.0.0-x86_64.rpm

# Portable AppImage (no installation required)
./Dvx3-BackupManager.AppImage --install-desktop-file  # optional .desktop file

# Snap
sudo snap install dvx3-backup-manager

# Flatpak
flatpak install flathub com.tadaka9.Dvx3BackupManager
```

### Standalone Binary (for portable usage)

Download the latest release from [Releases](https://github.com/tadaka9/Dvx3-Backup-Manager/releases/latest):

- **Linux**: `Dvx3-BackupManager.AppImage` or `.deb`/`.rpm`
- **macOS**: `Dvx3-Backup-Manager.dmg` (Intel) or `Dvx3-Backup-ARM64.dmg` (Apple Silicon)
- **Windows**: `Dvx3-Backup-Manager-x64.msi` or `Dvx3-Backup-Manager-arm64.exe`

Place the binary in your PATH and run:

```bash
export PATH="$HOME/.local/bin:$PATH"  # Linux
# or just move it to a folder you have in PATH
./backup-manager list
```

### From Source

See [BUILD.md](BUILD.md) for full build instructions. TL;DR:

```bash
git clone https://github.com/tadaka9/Dvx3-Backup-Manager.git
cd Dvx3-Backup-Manager
./build.sh all
sudo ./install.sh
```

### macOS Intel / Silicon

#### Apple Silicon (M1/M2/M3)

```bash
brew install valac pkg-config cmake ninja-build qt6 base64-cli librsvg appstream-util
./build.sh manager --target=arm64-apple-darwin
./build.sh gui --target=arm64-apple-darwin
open build/Dvx3-Backup-Manager-arm64.dmg
```

#### Intel Mac (x86_64)

```bash
brew install valac pkg-config cmake ninja-build qt6 base64-cli librsvg appstream-util
./build.sh manager --target=x86_64-apple-darwin
./build.sh gui --target=x86_64-apple-darwin
open build/Dvx3-Backup-Manager-x86_64.dmg
```

### Windows x64 / ARM64

#### MSVC (x64 native)

```powershell
choco install valac cmake ninja-build zip mingw-w64
.\build.sh manager
.\build.sh gui
```

#### Cross-compiled for Windows ARM64 (via MinGW-w64 from x64 runner):

The CI builds this automatically. For local cross-compilation, you'll need:

- **mingw-w64** installed via `choco install mingw-w64`
- Or use a WSL2 ARM runner (native Windows 11 ARM hardware)

---

## Building from Source

### Prerequisites

Before building, ensure the following dependencies are installed on your system:

| Platform | Dependencies |
|----------|-------------|
| **Linux** | `valac`, `pkg-config`, `cmake`, `ninja-build`/`make`, `qt6-base-dev`, `libglib2.0-dev`, `libjson-glib-dev`, `libsodium-dev`, `zstd`, `appstream-util`, `desktop-file-utils` |
| **macOS** | `valac`, `pkg-config`, `cmake`, `ninja-build`, `qt6-base-dev`, `libglib2.0-dev`, `libsodium-dev`, `zstd` (via Homebrew) |
| **Windows** | MSVC toolchain + Vala compiler, or MinGW-w64 cross-toolchain for ARM64 targets |

---

### Linux Build

```bash
sudo apt install valac pkg-config cmake ninja-build qt6-base-dev libglib2.0-dev libjson-glib-dev libsodium-dev zstd appstream-util desktop-file-utils squashfs-tools
./build.sh all          # build everything (core + manager + GUI)
./scripts/run-tests.sh  # run the test suite
```

---

### macOS Build

```bash
brew install valac pkg-config cmake ninja-build zip qt6 base64-cli librsvg appstream-util
./build.sh manager      # builds core library and CLI tool
./build.sh gui          # builds Qt6 GUI application
```

> 💡 On Apple Silicon (macOS ARM64), the `--target=aarch64-apple-darwin` flag is used automatically. On Intel Macs, use `--target=x86_64-apple-darwin`.

---

### Windows Build (MSVC)

```powershell
choco install valac cmake ninja-build zip mingw-w64
.\build.sh manager      # builds core library and CLI tool
.\build.sh gui          # builds Qt6 GUI application
```

For **Windows ARM64** cross-compilation, use the MinGW-w64 toolchain:

```powershell
$mingwPath = "C:\Program Files\mingw-w64\x86_64-ucrt-posix-seh-gcc-12-win32"
$env:CC     = "$mingwPath\bin\gcc.exe"
$env:CXX    = "$mingwPath\bin\g++.exe"
$env:CFLAGS = "-m64 -mcpu=armv8-a+fp+simd+crypto+crc"
./build.sh manager --target=wasm32-wasi   # or use aarch64-windows-msvc if toolchain supports it
```

---

### Cross-compilation Matrix in CI

The project uses GitHub Actions with a matrix strategy to build/test across all platform combinations:

- **Linux x86_64** → DEB, RPM, AppImage (x86_64)
- **Linux ARM64** → DEB, RPM, AppImage (aarch64) via QEMU emulation + native cross-compilation
- **macOS Intel** → DMG (x86_64)
- **macOS Silicon** → DMG (arm64) natively on `macos-15` runner
- **Windows x64** → MSI/NSIS (native MSVC build)
- **Windows ARM64** → cross-compiled via MinGW-w64 from x86_64 runner

All builds are validated in CI before release. See `.github/workflows/ci.yml` for the full matrix configuration.

---

## CLI Usage Reference

### Core Commands

```bash
dvx3 encrypt <SOURCE> -p "PASSWORD" [-o OUTPUT] [--exclude PATTERN...] [--include PATTERN...] [--compression LEVEL]
dvx3 decrypt <INPUT> -p "PASSWORD" [-o DESTINATION] [--password-salt-file SALT_FILE]
dvx3 list                     # list all configured backup jobs (interactive mode)
dvx3 run "<JOB_NAME>"        # trigger a specific backup job by name
dvx3 status                   # show current status of all jobs
dvx3 history                  # view backup operation history
dvx3 cleanup --keep 7         # remove old backups older than N days
```

### Interactive Mode (TUI)

Run `./backup-manager` or `dvx3` without arguments for a full-screen TUI:

1. **List** — show all configured backup jobs
2. **Add** — add a new backup job with custom paths, exclude/include rules, compression level
3. **Remove** — delete a job from the configuration
4. **Run** — trigger an immediate backup of a selected job
5. **History** — view chronological log of all past backups
6. **Restore** — restore files from any previous backup snapshot
7. **Cleanup** — remove expired backups according to retention policy
8. **Exit** — quit the application

### Non-interactive Scripting Mode

```bash
# List all jobs (JSON output)
./backup-manager list --format json

# Run a specific job non-interactively
./backup-manager run "Documents" --output /backups/documents-$(date +%Y%m%d).dvx3

# View history as CSV
./backup-manager history --format csv > backup-history.csv

# Show status summary
./backup-manager status --json
```

---

## Qt6 GUI

### Screenshots

<div align="center">
  <img src="./gui/qt/qtdesktop/screenshot_main_window.png" alt="Main Window" width="70%">
  <br>
  <small>Dvx3 Backup Manager — Main Window (Qt6)</small>
</div>

<div align="center">
  <img src="./gui/qt/qtdesktop/screenshot_job_editor.png" alt="Job Editor" width="70%">
  <br>
  <small>Edit a backup job: set paths, exclusions, compression level, retention policy</small>
</div>

### Features & Shortcuts

| Feature | Description |
|---------|-------------|
| **Drag-and-Drop** | Drop folders/files directly into the "Add Job" area |
| **Job Editor** | Full-featured editor: paths, exclusions (glob patterns), inclusion rules, compression level (1–22), encryption password management, retention policy |
| **Visual Progress Bar** | Real-time progress with ETA and throughput stats |
| **Log Viewer** | Expandable log panel showing per-file operations (skipped, compressed, encrypted) |
| **Backup History Table** | Sort/filter by date, size, status; click any row to restore from that snapshot |
| **Dark/Light Mode** | Toggle via system theme or manual switch |

---

## C++ / Vala API Usage

### C++ Example

```cpp
#include "dvx3.hpp"
#include <iostream>
#include <string>

int main(int argc, char* argv[]) {
    try {
        std::string source = "/home/user/documents";
        std::string output = "backup.dvx3";
        std::string password = "mysecretpassword123!";
        int compression_level = 9;

        dvx3::encrypt(source, output, password, compression_level);
        std::cout << "Backup created: " << output << "\n";
    } catch (const dvx3::Exception& e) {
        std::cerr << "Error: " << e.what() << "\n";
        return 1;
    }
    return 0;
}
```

### Vala Example

```vala
using Dvx3;

void encrypt_example () {
    var src = File.new_for_path("/my/folder");
    var dst = File.new_for_path("backup.dvx3");
    Dvx3.encrypt(src, dst, "password", 9);
}
```

See [CPP_USAGE.md](CPP_USAGE.md) for more examples.

---

## Archive Internals (Format)

The `.dvx3` archive format consists of:

1. **JSON header** (4 bytes length prefix):
   - `salt`: base64-encoded 256-bit random salt
   - `chunks_count`: number of encrypted chunks
   - `last_chunk_size`: size of the final chunk (for padding handling)
   - `argon2_params`: `{ "iterations": 8, "memory_mb": 64, "parallelism": 4 }`

2. **Encrypted chunks** (repeat N times):
   - 24-byte nonce (random per chunk)
   - Ciphertext: `(plaintext_size + 16)` bytes = XSalsa20 encrypted data + Poly1305 authentication tag
   - Chunk size: `~1 MiB` (configurable via `--chunk-size`)

Decryption iterates through all chunks, decrypts each one, and verifies the Poly1305 MAC before concatenating the plaintext.

---

## Configuration Files

| File | Purpose |
|------|---------|
| `~/.config/backup-manager/backup-manager.conf` | Job definitions (paths, exclusions, passwords) |
| `~/.config/backup-manager/backup-history.log` | Append-only log of every backup operation |
| `~/.config/backup-manager/passwords.dat` | Encrypted master password salt (optional) |

---

## Security Considerations

### Password Best Practices

- Use **12+ character** passwords with mixed case, digits, and special characters.
- Store the config file with restrictive permissions:
  ```bash
  chmod 600 ~/.config/backup-manager/backup-manager.conf
  chmod 400 ~/.config/backup-manager/passwords.dat
  ```
- Consider using a **passphrase manager** (e.g., KeePassXC, Bitwarden) to store the master password.

### File Permissions

The backup manager preserves source file permissions in archives. When extracting, files are restored with their original modes:

```bash
./backup-manager run "Documents" --preserve-permissions
```

### Entropy Sources (for key generation)

- `/dev/urandom` on Linux
- `arc4random` on macOS
- `GetRandomness` API on Windows

---

## Troubleshooting & FAQ

| Problem | Solution |
|---------|----------|
| "Error: missing dependency: valac" | Install Vala compiler: `apt install valac`, `brew install valac`, or `choco install valac` |
| "Error: pkg-config dependency not found: gio-2.0" | Run `sudo apt install libglib2.0-dev` (Linux) |
| Qt6 GUI won't launch on macOS ARM64 | Use the Apple Silicon build (`--target=arm64-apple-darwin`) or use the Intel cross-build DMG |
| "Password wrong" | The password must match exactly — case-sensitive. Check for trailing spaces or typos. |
| AppImage won't start on Linux | Run `chmod +x Dvx3-BackupManager.AppImage` and ensure you have a compatible runtime (glibc, Qt6) installed |

---

## Contributing

### Development Workflow

1. **Fork** the repository
2. **Create** a feature branch: `git checkout -b feat/my-awesome-feature`
3. **Make** your changes
4. **Run tests locally**: `./scripts/run-tests.sh`
5. **Lint**: `./scripts/run-lint.sh`
6. **Commit**: with clear, conventional commit messages
7. **Push** and open a pull request

### Running Tests Locally

```bash
# Run the test suite (C++ unit tests)
./scripts/run-tests.sh

# Or run individual tests:
cd build/tests && ./test-simple-backup
cd build/tests && ./test-exclusion
```

### Linting & Code Quality

The project uses `shellcheck` for shell scripts, `yamllint` for YAML workflows, and `actionlint` for workflow syntax validation. Run locally with:

```bash
./scripts/run-lint.sh
```

Install the required tools on Debian/Ubuntu:

```bash
sudo apt install yamllint shellcheck
go install github.com/rhysd/actionlint/cmd/actionlint@latest
```

---

## Changelog / Release Notes

See [RELEASE_NOTES.md](RELEASE_NOTES.md) for a full history of changes, bug fixes, and breaking changes.

| Version | Date | Highlights |
|---------|------|------------|
| 1.0.0 (beta) | Oct 2025 | Initial release with CLI, Qt6 GUI, C++/Vala API |
| 0.9.0 | Aug 2025 | First stable release; added AppImage packaging |

---

## License

Dvx3 Backup Manager is distributed under the **MIT License** — see [LICENSE](LICENSE) for details.

© 2025 tadaka9 — All rights reserved.