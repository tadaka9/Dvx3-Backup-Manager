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
- [Releasing](#releasing)
- [License](#license)

---

## Features

- **End-to-end encryption**: Argon2id KDF, XSalsa20-Poly1305 authenticated encryption
- **zstd compression**: Level 1-22, multi-threaded
- **No intermediate files**: Streams tar | zstd | encrypt
- **Progress tracking**: Dynamic (GNU tar) or static estimation
---

## Quick Start

```bash
# Build everything (CLI, GUI, library)
./build-all.sh
 mkdir -p tests/build
 cd tests/build
 cmake -G Ninja -S .. -B . -DCMAKE_BUILD_TYPE=Release
 cmake --build . --parallel
 ctest --output-on-failure
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
# generate generated C sources into a build-specific location to avoid checking them into git
# preferred: build/gen-c
valac -C -d build/gen-c libdvx3.vala
# or (legacy): valac -C -d gen-c libdvx3.vala
# or run the GUI build script which will generate them:
./build_gui.sh
```

**Linux:**
```bash
./build_gui.sh
```

## Contributing / Local Linting

CI no longer runs the lint job automatically — to validate linting and workflow correctness locally, run:

```bash
chmod +x scripts/run-lint.sh
./scripts/run-lint.sh
```

This will run `yamllint` on workflow files, `actionlint` on workflows, and `shellcheck` on shell scripts if these tools are installed locally. On Debian/Ubuntu, install them using `sudo apt-get install -y yamllint shellcheck` and `go install github.com/rhysd/actionlint/cmd/actionlint@latest` for `actionlint`.

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

CI updates: The project CI now contains macOS ARM64 and Windows ARM64 (MSVC) build/test steps and improves caching across platforms to speed up runs.

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

---

## Releasing

This project uses GitHub Actions for building, packaging, and publishing release artifacts. The main ideas are:

- Build artifacts are created under `build/Releases/<platform>/<arch>` during CI builds and when run locally via `./build_gui.sh`.
- A file `artifacts.txt` is now generated by `build_gui.sh` with newline-separated **relative** paths of the files that should be packaged (for example: `backup-manager-gui`, `lib/libdvx3.dylib`, `Dvx3-Run.sh`). The packaging workflow reads this file to copy only the listed artifacts into the release bundle.
- If `artifacts.txt` is not present, the CI packaging step falls back to copying the whole `build/Releases/<platform>/<arch>` and will attempt to flatten nested directories (e.g. `mac/arm64/mac/arm64`) into the root of the release tarball.
- Example artifact layout inside the final archive for macOS (arm64):

    - `backup-manager-gui` or `Dvx3 Backup Manager.app` (top-level)
    - `lib/libdvx3.dylib`
    - Plugin files under `plugins/` or `Contents/Plugins` depending on platform
    - Shared libs such as `libb2.so`, `libbrotli*`, `libzstd.so` or bundled frameworks

### Release triggers

- Tag-based publishing: The workflow is configured to run the `publish-release` step only for repository refs that are tags (for example `refs/tags/v1.2.3`). To publish a release via the normal pipeline, create a tag like `v1.2.3` and push it to GitHub.
- Manual publish via workflow_dispatch: You can also run the release workflow manually from the Actions page and provide a `release_tag` parameter. This will trigger `publish-release` for the provided tag.

Example: To dispatch a release from the Actions UI, provide these inputs (if present):

    - `release_tag`: the tag name to publish (e.g. v1.2.3)
    - `strict_artifact_checks`: `true`/`false` — whether to fail the jobs if any expected artifacts are missing. Default is `true`.

### Strict artifact checks

To avoid publishing incomplete release artifacts, `build_gui.sh` writes `artifacts.txt` and also enforces a set of critical artifacts by default using `STRICT_BUILD_ARTIFACTS=1`. If `STRICT_BUILD_ARTIFACTS=1` and a required artifact is missing, the build will fail.

If you want to override the strict checks for any given run, you can set `STRICT_BUILD_ARTIFACTS=0` or run the workflow with `strict_artifact_checks=false` as input to the dispatch. This should only be used for debugging or special circumstances.

### Required secrets and inputs for publishing

The `publish-release` workflow uses the standard `GITHUB_TOKEN` for the release API as well as optional GPG signing keys for signed releases. Ensure the repository `Secrets` include the following as needed:

    - `GITHUB_TOKEN` (automatically set by GitHub Actions) — used to create releases and upload artifacts
    - `GPG_PRIVATE_KEY` — required only if you enable GPG signing during release creation (store as base64 or raw as placed in Actions, and make sure the workflow has access to it)

If `publish-release` fails with `No tag found in ref or input!`, confirm the run was triggered by a tag push or that you provided `release_tag` in `workflow_dispatch`.

### Smoke tests and QA

The CI workflow includes a `smoke-test` job which downloads the generated release tarball and checks for the most important items using a small grep set, such as:
- `\.app/|backup-manager-gui|lib/libsodium|libb2|libdvx3|Contents/Plugins|Contents/Frameworks`

If `smoke-test` fails or the artifact does not contain expected files, confirm the following locally:

1. Run the `build_gui.sh` script and inspect `build/Releases/<platform>/<arch>/artifacts.txt`.
2. Confirm the files listed in `artifacts.txt` are present under `build/Releases/<platform>/<arch>`.
3. If a file is missing, re-check the packaging and the `build_gui.sh` run logs for failures or plugin copy issues.
4. For nested layouts (e.g. `mac/arm64/mac/arm64`), `build_gui.sh` and the CI packaging should flatten the structure, but it is always safer to ensure `artifacts.txt` contains the final relative paths you expect in the release root.

### Manual release example (workflow_dispatch)

Open the repository Actions tab → Select the `publish-release` workflow → Run workflow and set the `release_tag` input to the tag you want to publish (such as `v1.2.3`). Optionally set `strict_artifact_checks=false` for debugging runs.

### Troubleshooting

- `No tag found in ref or input!`: Ensure a tag was pushed to the repository (i.e. `git tag v1.2.3 && git push origin v1.2.3`) or use `workflow_dispatch` and provide `release_tag`.
- Missing files or unexpected layouts: Re-run the `build_gui.sh` locally and inspect `build/Releases/<platform>/<arch>/artifacts.txt` and the content of the release tarball. Verify `backup-manager-gui` or `.app` is present at the top-level.
- macOS builds: The project currently targets macOS ARM64 builds using `macos-latest`. If you require universal macOS builds you will want to reintroduce separate x86_64 macOS CI runners and adjust the packaging job accordingly.

---

