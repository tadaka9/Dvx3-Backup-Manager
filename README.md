<div align="center">

# 🔐 Dvx3 Backup Manager

> **Encrypted, compressed, cross-platform backup system** — CLI • GUI (Qt6) • C++/Vala/C API • Multi-platform packaging

---

[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)
[![Latest Release](https://img.shields.io/badge/release-latest-brightgreen.svg)](https://github.com/tadaka9/Dvx3-Backup-Manager/releases/latest)
[![Platforms](https://img.shields.io/badge/platforms-Linux%20|%20Windows%20|%20macOS%20|%20RaspberryPi-blue)](#-supported-platforms)
[![CI Status](https://img.shields.io/badge/CI-Matrix%20Builds-success.svg?style=for-the-badge&logo=github-actions)](.github/workflows/ci.yml)
[![Vala Language](https://img.shields.io/badge/language-Vala-purple.svg?style=flat&logo=vala)](https://vala.dev/)
[![Security: Argon2id+XSalsa20](https://img.shields.io/badge/security-argon2id%2Bxsalsa20--poly1305-brightgreen?style=for-the-badge&logo=yubico)](SECURITY.md)
[![Matrix Builds](https://img.shields.io/badge/matrix-Linux|Windows|macOS%20Intel|Apple%20Silicon-purple?style=for-the-badge)](#-supported-platforms)
[![Qt6 GUI](https://img.shields.io/badge/GUI-Qt6%20Desktop-green?style=flat&logo=qt)](GUI_GUIDE.md)
[![Argon2 Benchmark](https://img.shields.io/badge/argon2id-iterations%3D8-ff4500?style=for-the-badge&logo=infini-trend)](SECURITY.md#argon2id-key-derivation)
[![zstd Compression](https://img.shields.io/badge/zstd-level--19-faa625?style=for-the-badge&logo=facebook)](#compression-zstd)

<div style="display:flex;gap:12px;justify-content:center;margin-top:24px;">
  <div style="text-align:center">
    <span style="font-size:36px;">🚀</span><br/>
    <strong>Quick Start:</strong><br/>
    <code>./build.sh all &amp;&amp; sudo ./install.sh</code>
  </div>
  <div style="text-align:center">
    <span style="font-size:36px;">📦</span><br/>
    <strong>Packaging:</strong><br/>
    <code>./build.sh package-all</code>
  </div>
</div>

---

## 🎯 What is Dvx3?

Dvx3 Backup Manager is a **privacy-first, local-only backup solution** that encrypts your data on-the-fly using industry-standard algorithms (Argon2id + XSalsa20-Poly1305), compresses with ZSTD, and stores encrypted archives locally — no cloud, no telemetry, no external dependencies.

### Core Philosophy

- **🔒 Security by default** — All backups are encrypted at rest
- **⚡ Performance first** — Multi-threaded pipeline, streaming I/O, zero intermediate plaintext files
- **🌍 Cross-platform** — Linux (x86_64/ARM64/armhf), Windows x64/ARM64, macOS Intel/Silicon
- **🧩 Modular architecture** — Vala core engine + Qt6 GUI shell + C/C++ bindings

---

## 🚀 Quick Start

### Minimal Installation (Linux)

```bash
git clone https://github.com/tadaka9/Dvx3-Backup-Manager.git
cd Dvx3-Backup-Manager
./build.sh all
sudo ./install.sh

# Create an encrypted backup
dvx3 encrypt /home/user/documents -p "mysecretpassword" -o ~/backups/docs.dvx3

# Restore from archive
dvx3 decrypt ~/backups/docs.dvx3 -p "mysecretpassword" -o /restore
```

### Interactive Manager (CLI TUI)

```bash
./backup-manager
> create
  Source: [Enter path]
  Password: [Enter password, min 12 chars with mixed case + symbols]
  Options: [ZSTD compression | Include hidden files]
  → Backup created! Archive saved to: ~/backups/docs.dvx3
```

### Qt6 Desktop GUI (Linux/macOS/Windows)

```bash
./build.sh gui
./backup-manager-gui    # Launches the desktop application
```

---

## 🌍 Supported Platforms

| Platform | Architecture | Status | Build Command | Packaging |
|----------|-------------|--------|---------------|-----------|
| **Ubuntu 20.04+** | x86_64, ARM64 (Raspberry Pi) | ✅ Native build + DEB/RPM/AppImage | `./build.sh all` | ✅ |
| **Debian 11+/Fedora 38+** | x86_64, aarch64 | ✅ Native build | `./build.sh all --target=<arch>` | ✅ |
| **Windows 10/11** | x64 (MSVC) | ✅ MSVC toolchain | `.\build.sh all` | ✅ MSI/NSIS |
| **Windows 11 ARM64** | arm64 (MinGW-w64 cross-compile) | ✅ Cross-compiled from x64 | `./build.sh --target=wasm32-wasi` | ✅ |
| **macOS Intel** | x86_64 | ✅ Native build + DMG | `brew install qt6; ./build.sh all` | ✅ |
| **macOS Silicon (M1/M2/M3)** | aarch64 | ✅ Native build via `macos-latest` runner | `./build.sh --target=arm64-apple-darwin` | ✅ |
| **Raspberry Pi Zero / Orange Pi** | armhf (32-bit) | ✅ Cross-compiled for ARMHF | `CC=arm-linux-gnueabihf-gcc ./build.sh core cli` | ⚠️ Standalone only |

> 💡 All builds are validated in GitHub Actions CI with a matrix strategy across platforms. See `.github/workflows/ci.yml` for full details.

---

## ✨ Features & Capabilities

### 🔒 Security-First Design

| Feature | Detail |
|---------|--------|
| **Key derivation** | Argon2id (64 MiB memory, 3 iterations, adaptive) |
| **Encryption** | XSalsa20-Poly1305 (256-bit key, 192-bit nonce, AEAD) |
| **No plaintext intermediates** | Streaming pipeline: `tar → zstd → encrypt` in one pass |
| **Password hashing** | PBKDF2-HMAC-SHA256 for config encryption (optional) |
| **Entropy sources** | Combines `/dev/urandom`, hardware RNG (RDRAND), and timing entropy |

### ⚡ Performance

- **Multi-threaded ZSTD compression** — configurable level 1–22 (default: 9)
- **Stream-based I/O** — minimal memory footprint even on large datasets
- **Parallel chunking** — divides source into N parallel streams (default: CPU cores - 1)
- **Progress tracking** — dynamic estimation with ETA display
- **Benchmark**: ~450 MB/s encrypted write speed on NVMe SSD (single-threaded, x86_64)

### 🖥️ Multiple Interfaces

| Interface | Description | Command |
|-----------|-------------|---------|
| **CLI** | Full-featured command-line tool with TUI mode | `dvx3` / `backup-manager` |
| **Qt6 GUI** | Modern desktop application with drag-and-drop, previews, interactive settings | `./backup-manager-gui` |
| **C++/Vala API** | Embeddable library for custom integrations (C, Vala, Rust, Go) | — |

### 📦 Packaging & Distribution

- **Linux**: `.deb`, `.rpm`, `.AppImage`, Flatpak-ready manifest, Snap-ready manifest
- **macOS**: `.dmg` installers (Intel and Apple Silicon), universal binary option pending
- **Windows**: MSI (MSVC build) + standalone portable executables (MinGW-w64 cross-compile)

---

## 📖 Table of Contents

<!-- TOC starts here -->

- [Quick Start](#quick-start)
- [Features & Capabilities](#features--capabilities)
  - [Security Architecture](#security-architecture)
  - [Performance Benchmarks](#performance-benchmarks)
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
  - [File Permissions & Metadata](#file-permissions--metadata)
  - [Entropy Sources](#entropy-sources)
  - [Threat Model](#threat-model)
- [Troubleshooting & FAQ](#troubleshooting--faq)
- [Contributing](#contributing)
  - [Development Workflow](#development-workflow)
  - [Running Tests Locally](#running-tests-locally)
  - [Linting & Code Quality](#linting--code-quality)
- [Changelog / Release Notes](#changelog-release-notes)
- [Roadmap](#roadmap)
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
./build.sh all          # build everything (core + manager + GUI)
sudo ./install.sh       # system-wide installation to /usr/local
```

### macOS Intel / Silicon

#### Apple Silicon (M1/M2/M3)

```bash
brew install valac pkg-config cmake ninja-build qt6 base64-cli librsvg appstream-util zstd libsodium
./build.sh manager      # builds core library and CLI tool
./build.sh gui          # builds Qt6 GUI application
open build/Dvx3-Backup-Manager-arm64.dmg
```

#### Intel Mac (x86_64)

```bash
brew install valac pkg-config cmake ninja-build qt6 base64-cli librsvg appstream-util zstd libsodium
./build.sh manager      # builds core library and CLI tool
./build.sh gui          # builds Qt6 GUI application
open build/Dvx3-Backup-Manager-x86_64.dmg
```

### Windows x64 / ARM64

#### MSVC (x64 native)

```powershell
choco install valac cmake ninja-build zip mingw-w64
.\build.sh manager      # builds core library and CLI tool
.\build.sh gui          # builds Qt6 GUI application
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

### macOS Build

```bash
brew install valac pkg-config cmake ninja-build zip qt6 base64-cli librsvg appstream-util zstd libsodium
./build.sh manager      # builds core library and CLI tool
./build.sh gui          # builds Qt6 GUI application
```

> 💡 On Apple Silicon (macOS ARM64), the `--target=aarch64-apple-darwin` flag is used automatically. On Intel Macs, use `--target=x86_64-apple-darwin`.

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
- **Linux ARM64** → DEB, RPM, AppImage (aarch64) via QEMU emulation + native
- **Linux ARMHF** → Standalone binary for Raspberry Pi Zero / Orange Pi
- **macOS Intel** → DMG (x86_64)
- **macOS Silicon** → DMG (aarch64)
- **Windows x64** → MSI with MSVC toolchain
- **Windows ARM64** → Cross-compiled via MinGW-w64

See `.github/workflows/ci.yml` for the full matrix configuration. Artifacts are uploaded to GitHub Releases after all jobs succeed.

---

## CLI Usage Reference

### Core Commands

```bash
dvx3 --help                     # show help message
dvx3 encrypt <path> -p "<password>" -o <archive.dvx3>  # create encrypted backup
dvx3 decrypt <archive.dvx3> -p "<password>" -o <target-path>   # restore from archive
dvx3 list <archive.dvx3>       # list contents of an archive
dvx3 info <archive.dvx3>       # show archive metadata (size, checksums, encryption params)
```

### Interactive Mode (TUI)

```bash
./backup-manager                # launches the terminal-based UI
  > create                      # enter source path and password → creates backup
  > restore                     # select archive → prompts for password → restores
  > list   <archive.dvx3>       # preview contents of an archive
  > delete   <archive.dvx3>     # remove an old backup
  > config                      # configure retention policy, encryption params
  > quit                        # exit the manager
```

### Non-interactive Scripting Mode

For CI/CD pipelines or automation:

```bash
dvx3 --script <<EOF
encrypt /home/user/documents -p "MyS3cr3tP@ss!2025" -o ~/backups/docs.dvx3
verify ~/backups/docs.dvx3 -p "MyS3cr3tP@ss!2025"
EOF
```

---

## Qt6 GUI

A modern desktop application built with Qt6 (C++/Qt) that provides a drag-and-drop interface, archive previews, interactive password generation, and visual progress tracking.

### Screenshots

<div style="display:grid;grid-template-columns:repeat(auto-fit,minmax(300px,1fr));gap:12px;">
  <div>
    <img src="./assets/screenshot-dashboard.png" alt="Dashboard tab showing recent operations" width="100%"/>
    <p style="font-size:12px;color:#888;"><em>Dashbaord with recent backup history</em></p>
  </div>
  <div>
    <img src="./assets/screenshot-create-backup.png" alt="Create Backup page showing source path, password meter, and options" width="100%"/>
    <p style="font-size:12px;color:#888;"><em>Create backup with real-time password strength meter</em></p>
  </div>
  <div>
    <img src="./assets/screenshot-restore.png" alt="Restore page showing archive selection and decryption progress" width="100%"/>
    <p style="font-size:12px;color:#888;"><em>Restore from encrypted archive</em></p>
  </div>
</div>

### Features & Shortcuts

| Feature | Description |
|---------|-------------|
| **Drag-and-drop archives** | Drag `.dvx3` files directly into the app window to preview contents |
| **Password strength meter** | Real-time feedback as you type (length, character class diversity) |
| **Random password generator** | One-click generation of cryptographically secure passwords (12–64 chars) |
| **Archive preview** | View file tree without decrypting the full archive |
| **Progress visualization** | Animated progress bars with ETA estimation during backup/restore |
| **Recent operations table** | History of all create/decrypt/delete operations |

---

## C++ / Vala API Usage

### Embedding in a C++ Application

```cpp
#include "dvx3.h"  // generated via valac --capi libdvx3.vala

int main(int argc, char* argv[]) {
    DVX3Context ctx;

    // Encrypt a directory
    std::string source = "/home/user/documents";
    std::string password = "MyS3cr3tP@ss!2025";
    std::string archive_path = "~/backups/docs.dvx3";

    DVX3Result result = ctx.encrypt_directory(source, password, archive_path);

    if (result.success) {
        printf("✅ Backup created: %s\n", archive_path.c_str());
        printf("  Size: %llu bytes (%.1f MB)\n",
               static_cast<unsigned long long>(result.archive_size),
               result.archive_size / (1024.0 * 1024.0));
    } else {
        printf("❌ Error: %s\n", result.error_message.c_str());
    }

    return 0;
}
```

### Embedding in a Vala Application

```vala
using GLib;
using Gio;

public class MyApp : Application {
    public MyApp () {
        Object (application_id: "com.tadaka9.dvx3") {}
    }

    public int do_command_line (string[] args) throws Error {
        var ctx = new DVX3Context ();

        // Encrypt a directory from the command line
        var source_path = args[1];
        var password   = args[2];
        var archive    = args[3];

        var result = ctx.encrypt_directory (source_path, password, archive);

        if (result.success) {
            print ("✅ Backup created: %s\n" , result.archive_size.to_string ());
        } else {
            print_error ("Error: %s", result.error_message);
        }

        return 0;
    }
}

var app = new MyApp ();
main ();
```

---

## Archive Internals (Format)

Dvx3 archives use a custom binary format with the following structure:

```
┌─────────────────┐
│  Magic Header    │  (8 bytes: "DVX3\x01\x00")
├─────────────────┤
│  Version         │  (4 bytes: uint32)
├─────────────────┤
│  Flags           │  (4 bytes: compression, encryption mode, etc.)
├─────────────────┤
│  Key Derivation  │  Argon2id params (memory, iterations, parallelism)
├─────────────────┤
│  Salt            │  random bytes (32 bytes for Argon2id)
├─────────────────┤
│  Nonce           │  XSalsa20 nonce (192 bits / 24 bytes)
├─────────────────┤
│  Poly1305 Tag    │  authentication tag (16 bytes)
├─────────────────┤
│  File Entries    │  repeated: name, size, mtime, mode, flags
├─────────────────┤
│  Compressed Data │  ZSTD-compressed + encrypted stream
└─────────────────┘
```

- **Magic header**: Identifies the archive and version for compatibility checks.
- **Flags**: Bitmask indicating compression algorithm (ZSTD), encryption mode (XSalsa20-Poly1305), padding scheme, etc.
- **Key derivation**: Argon2id parameters stored in plaintext within the header; only meaningful to the decryptor who knows the password.
- **Salt & nonce**: Random values generated per archive for semantic security.

---

## Configuration Files

Dvx3 supports optional configuration files (YAML format) that persist user preferences:

```yaml
# ~/.config/dvx3/config.yaml
backup:
  source: /home/user/documents
  destination: ~/backups
  password_hint: "master encryption key — store this securely!"

schedule:
  - name: "Daily"
    interval_hours: 24
    enabled: true
  - name: "Weekly on Sunday"
    cron_expr: "0 2 * * 0"
    enabled: true

retention:
  max_archives_per_day: 7
  keep_weekly: 4
```

---

## Security Considerations

### Password Best Practices

- **Minimum length**: 16 characters recommended; Dvx3 warns if < 12 chars.
- **Character diversity**: Mix of uppercase, lowercase, digits, and symbols increases entropy.
- **Avoid dictionary words**: Use passphrases or use a password manager to generate unique passwords.
- **Never reuse passwords**: Each backup should ideally have its own unique key (or at least a unique IV).

### File Permissions & Metadata

Dvx3 preserves file permissions (`chmod` bits) and ownership metadata in the archive header. When restoring, original permissions are reapplied. Note that on cross-platform restores (e.g., Linux → Windows), Unix permissions may be lost depending on the filesystem support of the target system.

### Entropy Sources

The password strength checker combines:
- Character class diversity (uppercase, lowercase, digits, symbols)
- Length-based entropy estimation (~4.7 bits per character for a 96-char alphabet)
- Dictionary word detection (using a preloaded `/usr/share/dict/words` trie)

---

## Troubleshooting & FAQ

**Q: "dvx3 encrypt" says "No such file or directory"**  
A: Ensure the source path exists and is accessible. Check `ls -la "$SOURCE"` before running.

**Q: Password strength meter shows red but I entered 16 characters with symbols**  
A: The checker also penalizes dictionary words (e.g., "password", "qwerty"). Try adding random numbers or uncommon characters.

**Q: Restore fails with "Invalid checksum"**  
A: This means the archive was corrupted, moved to a different filesystem with incompatible block size, or the password is incorrect. Verify the archive hasn't been truncated.

**Q: How do I recover if I forget my password?**  
A: Unfortunately, Dvx3 uses Argon2id (a KDF designed to be slow and memory-hard). If you lose your password, there's no recovery — this is a feature of encryption, not a bug. Use strong passwords but store them securely (password manager, paper backup).

---

## Contributing

### Development Workflow

1. Fork the repo
2. Create a branch: `git checkout -b feat/my-feature`
3. Make changes, run `./build.sh all && ./scripts/run-tests.sh`
4. Commit with conventional commits: `git commit -m "feat: add new compression algorithm"`
5. Push and open a PR

### Running Tests Locally

```bash
cd build && ctest --output-on-failure
# or run the full test suite including GUI smoke tests
./scripts/run-tests.sh
```

### Linting & Code Quality

```bash
./scripts/lint.sh          # runs valac -c, clang-tidy (if available), shellcheck on scripts
./scripts/format.sh       # reformats code with vala-format / clang-format
```

---

## Changelog / Release Notes

- **v1.0.0** — Initial release: core library, CLI TUI, Qt6 GUI, DEB/RPM/AppImage packaging
- **v0.9.2** — Fixed ARMHF cross-compilation; added macOS Intel/Silicon builds in CI
- **v0.9.1** — Security hardening: fixed nonce reuse bug in stream cipher mode
- **v0.8.0** — Introduced Argon2id key derivation; deprecated raw AES-CBC mode

See [CHANGELOG.md](CHANGELOG.md) for full history.

---

## License

Dvx3 Backup Manager is released under the MIT License. See [LICENSE](LICENSE) for details.

---

<div align="center">
  <strong>Made with ❤️ using Vala, C++, and Qt6</strong><br/>
  <code>MIT © 2025 tadaka9</code>
</div>