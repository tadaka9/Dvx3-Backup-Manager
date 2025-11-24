[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)
[![platforms](https://img.shields.io/badge/platform-linux%20%7C%20macos%20%7C%20windows%20%7C%20raspberry--pi-blue)](BUILD_MULTIPLATFORM.md)
[![Qt6 GUI](https://img.shields.io/badge/GUI-Qt6-informational)](GUI_GUIDE.md)
[![Vala](https://img.shields.io/badge/language-vala-blueviolet)](https://vala.dev/)
[![C++](https://img.shields.io/badge/language-c++-blue)](CPP_USAGE.md)
[![Security: Argon2id+XSalsa20](https://img.shields.io/badge/security-argon2id%20%2B%20xsalsa20--poly1305-brightgreen)](SECURITY.md)

# Dvx3 Backup Manager

> **Encrypted, compressed, and cross-platform backup system with CLI, GUI, and C++/Vala/C API**

---

## Overview

Dvx3 Backup Manager is a secure, high-performance backup solution for Linux, macOS, Windows, and Raspberry Pi. It features:

- **Encrypted archives**: Argon2id KDF + XSalsa20-Poly1305 (libsodium)
- **Compression**: zstd (configurable level, multi-threaded)
- **Streaming pipeline**: No intermediate files, efficient memory usage
- **Multiple interfaces**: CLI, interactive TUI, Qt6 GUI, C++/Vala/C API
- **Backup job management**: Retention, history, automation, and more

---

## Table of Contents

- [Features](#features)
- [Quick Start](#quick-start)
- [Installation](#installation)
- [Building](#building)
- [CLI Usage](#cli-usage)
- [Interactive Backup Manager](#interactive-backup-manager)
- [Qt6 GUI](#qt6-gui)
- [C++/Vala API Usage](#cppvala-api-usage)
- [Archive Format](#archive-format)
- [Configuration & Files](#configuration--files)
- [Multi-Platform Builds](#multi-platform-builds)
- [Security](#security)
- [Troubleshooting](#troubleshooting)
- [License](#license)

---

## Features

- **End-to-end encryption**: Argon2id KDF, XSalsa20-Poly1305 authenticated encryption
- **zstd compression**: Level 1-22, multi-threaded
- **No intermediate files**: Streams tar | zstd | encrypt
- **Progress tracking**: Dynamic (GNU tar) or static estimation
- **Multiple backup jobs**: Each with retention, password, and history
- **Backup history**: Track all operations, sizes, and status
- **Retention policies**: Automatic cleanup of old backups
- **Cross-platform**: Linux, macOS, Windows, Raspberry Pi
- **Qt6 GUI**: Visual job management, progress, and history
- **C++/Vala/C API**: Use as a library in your own apps

---

## Quick Start

```bash
# Build everything (CLI, GUI, library)
./build-all.sh

# Run the interactive backup manager
./backup-manager

# Or launch the GUI
./backup-manager-gui

# Or use the CLI directly
./dvx3 encrypt /path/to/folder -p "password" -o backup.dvx3
./dvx3 decrypt backup.dvx3 -p "password" -o /restore/to
```

---

## Installation

See [INSTALL.md](INSTALL.md) for full details.

**System-wide:**
```bash
sudo ./install.sh
```

**User-only:**
```bash
PREFIX=~/.local ./install.sh
```

**Standalone:**
```bash
./build_backup_manager.sh
./backup-manager
```

---

## Building

**Prerequisites:**

Before building, ensure the following dependencies are installed on your system:

- Vala compiler (0.56+)
- GLib 2.0 development packages
- JSON-GLib development packages
- libsodium development packages
- zstd
- gcc/g++ with C++17 support
- Qt6 development libraries and tools

On Debian/Ubuntu, these can be installed with:

```bash
sudo apt-get install valac libglib2.0-dev libjson-glib-dev libsodium-dev zstd g++ qt6-base-dev
```

On Arch Linux, install with:

```bash
sudo pacman -S vala glib2 json-glib libsodium zstd gcc qt6-base
```

See [BUILD_MULTIPLATFORM.md](BUILD_MULTIPLATFORM.md) for platform-specific instructions.

## Developer setup

We provide a `pre-commit` hook and helper to enable hooks from the repository. Run this once to enable the local pre-commit hooks from `.githooks`:

```bash
./scripts/setup-hooks.sh
```

This sets `core.hooksPath` to `.githooks` and enables checks like blocking checked-in generated files.

Note: This repository does not track generated C sources in `gen-c/` by policy.
If you need to generate these files locally (for building or debugging), use one of:

```bash
# generate generated C sources into gen-c/
valac -C -d gen-c libdvx3.vala
# or run the GUI build script which will generate them:
./build_gui.sh
```

**Linux:**
```bash
./build_gui.sh
```
./build_gui.sh
sudo pacman -S vala glib2 json-glib libsodium zstd gcc qt6-base
sudo apt-get install valac libglib2.0-dev libjson-glib-dev libsodium-dev zstd g++ qt6-base-dev

**macOS:**
```bash
./build-macos.sh
```

**Windows (cross-compile):**
```bash
./build-windows.sh
```

**Raspberry Pi:**
```bash
./build-raspberry.sh
```

---

## CLI Usage

### Encrypt a folder
```bash
./dvx3 encrypt /path/to/folder -p "password" -o backup.dvx3
```

### Decrypt an archive
```bash
./dvx3 decrypt backup.dvx3 -p "password" -o /restore/to
```

**Options:**
- `-p, --password`   Password for encryption/decryption (required)
- `-o, --output`     Output file or directory
- `-i, --in-place`   Allow output inside source folder (excluded from archive)

---

## Interactive Backup Manager

Run `./backup-manager` for a menu-driven TUI:

1. List backup jobs
2. Add new backup job
3. Remove backup job
4. Run backup
5. View backup history
6. Restore from backup
7. Cleanup old backups
8. Show status
0. Exit

**Non-interactive mode:**
```bash
./backup-manager list
./backup-manager run "Job Name"
./backup-manager cleanup
```

See [BACKUP_MANAGER_GUIDE.md](BACKUP_MANAGER_GUIDE.md) for full details.

---

## Qt6 GUI

Run `./backup-manager-gui` for a modern graphical interface:

- Add/edit/remove backup jobs
- Configure compression, tar, and exclusion options
- Visual progress bar and log
- Backup history table
- Settings persistence

See [GUI_GUIDE.md](GUI_GUIDE.md) for screenshots and usage.

---

## C++/Vala API Usage

### C++ Example
```cpp
#include "dvx3.hpp"
#include <iostream>

int main() {
    try {
        dvx3::encrypt("/path/to/folder", "backup.dvx3", "password");
        dvx3::decrypt("backup.dvx3", "/restore/to", "password");
        std::cout << "Success!\n";
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
    Dvx3.encrypt(src, dst, "password");
}
```

See [CPP_USAGE.md](CPP_USAGE.md) for more.

---

## Archive Format

```
┌─────────────────────────────────────────┐
│ 4 bytes: JSON header length (BE)        │
├─────────────────────────────────────────┤
│ JSON header:                            │
│   - salt (base64)                       │
│   - chunks count                        │
│   - last_chunk_size                     │
│   - argon2 parameters                   │
├─────────────────────────────────────────┤
│ Encrypted chunks (repeat N times):      │
│   ┌─────────────────────────────────┐   │
│   │ 24 bytes: nonce                 │   │
│   ├─────────────────────────────────┤   │
│   │ ciphertext (1 MiB + 16 byte MAC)│   │
│   └─────────────────────────────────┘   │
└─────────────────────────────────────────┘
```

**Security parameters:**
- Argon2id: 2 iterations, 64MB, 4 threads
- XSalsa20-Poly1305: 256-bit key, 192-bit nonce, 128-bit MAC

---

## Configuration & Files

- `backup-manager.conf`: Backup job definitions
- `backup-history.log`: Backup operation history
- `libdvx3.vala`, `dvx3-cli.vala`, `dvx3.h`, `dvx3.hpp`: Library sources and headers
- `build*.sh`: Build scripts for all platforms
- `vala-extra-vapis/libsodium.vapi`: Vala bindings for libsodium

See [BACKUP_MANAGER_GUIDE.md](BACKUP_MANAGER_GUIDE.md) and [GUI_GUIDE.md](GUI_GUIDE.md) for details.

---

## Multi-Platform Builds

See [BUILD_MULTIPLATFORM.md](BUILD_MULTIPLATFORM.md) for full cross-platform build instructions (Linux, macOS, Windows, Raspberry Pi, Docker, CI/CD).

---

## Security

- Passwords are stored in plaintext in config files. **Set file permissions!**
  ```bash
  chmod 600 ~/.config/backup-manager/backup-manager.conf
  ```
- Use strong passwords (12+ chars recommended)
- All encryption uses Argon2id KDF and XSalsa20-Poly1305
- See [SECURITY.md](SECURITY.md) for policy and reporting

---

## Troubleshooting

- See [BACKUP_MANAGER_GUIDE.md](BACKUP_MANAGER_GUIDE.md) and [GUI_GUIDE.md](GUI_GUIDE.md) for common issues
- Ensure all dependencies are installed (see [INSTALL.md](INSTALL.md))
- For build errors, check Vala, GLib, JSON-GLib, libsodium, zstd, Qt6, and compiler versions
- For runtime errors, run from terminal to see logs
- For CLI/GUI password errors, verify you are using the correct password

---

## License

MIT License (c) 2025 tadaka9

See [LICENSE](LICENSE) for details.

---

## Repository

This project is hosted at: [https://gitlab.com/cryptoware/Dvx3-backup-manager.git](https://gitlab.com/cryptoware/Dvx3-backup-manager.git)
