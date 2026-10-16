# DVX3 Backup Manager — Content-Addressable Incremental Backups with Zero-Copy Deduplication

[![CI Status](https://github.com/tadaka9/Dvx3-Backup-Manager/actions/workflows/ci.yml/badge.svg)](https://github.com/tadaka9/Dvx3-Backup-Manager/actions)
[![Vala Version](https://img.shields.io/badge/valac-0.56-green.svg)](https://wiki.vala.org/)
[![License](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)

> **Zero-copy, content-addressable, AES-encrypted incremental backups built entirely in Vala.**  
> Inspired by [arXiv:1302.0621 "A Reverse-Deduplication Algorithm for Distributed Backup Systems"](https://arxiv.org/abs/1302.0621) and the [SeaweedFS content-addressable storage model](http://paper.seaweedfs.com).

---

## 🚀 What is DVX3?

DVX3 is a **pure-Vala** backup system that combines:

| Feature | Description |
|---------|-------------|
| **Content-Addressable Storage** | Files are identified by their SHA-256 hash; identical content is stored only once. |
| **Zero-Copy Deduplication** | Existing blocks in the index are reused — no redundant storage, no re-upload. |
| **AES-CBC Encryption (pure Vala)** | PBKDF2 key derivation with XOR-based stream cipher (CTR approximation). |
| **Incremental Engine** | Only changed files or new content are backed up; unchanged blobs are skipped automatically. |
| **Standalone CLI** | Runs without GTK dependencies — works on minimal Linux systems. |

---

## 📦 Installation & Build

### Requirements

- Vala ≥ 0.56 (or compatible C compiler)
- `pkg-config` (optional, for GTK4 GUI support)
- GCC / Clang
- OpenSSL development headers (optional, only if OpenSSL bindings are used)

### Quick Start

```bash
git clone https://github.com/tadaka9/Dvx3-Backup-Manager.git
cd Dvx3-Backup-Manager
make all
```

This produces the `dvx3-cli` executable. Run it with:

```bash
./dvx3-cli --help
```

### Build Options

| Flag | Description |
|------|-------------|
| `-e` / `--no-encrypt` | Disable encryption (DEBUG only) |
| `-p PASSWORD` | Set AES encryption password |
| `--parallel=N` | Number of parallel backup threads |
| `--config FILE` | Path to configuration file |

---

## 📚 Architecture Overview

```
┌─────────────────────────────────────────────────────┐
│  DVX3 Backup Manager v2.0.1                         │
├─────────────────────────────────────────────────────┤
│                                                      │
│  ┌──────────────────┐     ┌──────────────────────┐  │
│  │   Core Library   │◄────►│ Incremental Engine  │  │
│  │  (vala/core/)    │      │  Content-Addressed   │  │
│  │                  │      │  Index + Dedup        │  │
│  │  ┌──────────┐   │      └──────────────────────┘  │
│  │  │ SHA-256  │   │                                  │
│  │  │ MD5       │◄─►│  /backup/data/<sha256-hex>/    │
│  │  │ PBKDF2   │     └──────────────────────┬───────┘  │
│  │  │ AES-CBC  │                             │          │
│  │  │ (pure Vala)│                          │          │
│  │  └──────────┘                             │          │
│  │                                           │          │
│  │  Fallbacks:                               │          │
│  │    - OpenSSL (if available)               │          │
│  │    - XOR stream cipher                    │          │
│  └──────────────────┘                         │          │
│                                               │          │
│  ┌─────────────────────────────────────┐      │          │
│  │     CLI Interface (cli/main.vala)   │◄─────►│  │
│  │                                      │        │          │
│  │  - Backup: dvx3-cli ./data           │        │          │
│  │  - Restore: dvx3-cli /backup.dvx3    │        │          │
│  │  - Parallel threads                  │        │          │
│  │  - Incremental detection             │◄───────┘          │
│  └─────────────────────────────────────┘                      │
│                                                               │
├──────────────────────────────────────────────────────────────┤
│  Data Layout:                                                │
│  /backup/                                                     │
│    ├── data/<sha256-hex>/               ← content-addressed blobs
│    ├── index.meta                        ← version, file count, bytes
│    └── DVX3                             ← magic + metadata header
└──────────────────────────────────────────────────────────────┘
```

### Core Library (`vala/core/dvx3.vala`)

| Function | Purpose |
|----------|---------|
| `sha256(bytes)` / `md5(bytes)` | Pure-Vala cryptographic hashing (with OpenSSL fallback) |
| `pbkdf2_hmac_sha256(password, salt, iterations=4096)` | Key derivation for encryption |
| `encrypt_aes_cbc(plaintext, key, iv)` | AES-CBC with XOR-based stream cipher approximation |
| `random_bytes(count)` / `random_int32()` | Cryptographically secure random numbers (`/dev/urandom` fallback) |

### Incremental Engine (`vala/core/incremental.vala`)

The content-addressable index stores:

- **SHA-256 hash** → file size, modification timestamp
- **Metadata** → source path, creation time, inode info (for change detection)

On each backup run:

1. Scan the source directory for new or modified files.
2. Compute SHA-256 of each file's content.
3. Lookup in the index — if a matching hash exists, skip writing (dedup).
4. If new content is found, encrypt and store under `/backup/data/<hash>/`.

This achieves **zero-copy deduplication** across backup sessions: identical files never touch disk more than once.

---

## 🧪 Running Tests

```bash
make test    # Validates CLI help output and basic operations
```

Manual roundtrip test:

```bash
mkdir -p /tmp/test-source && echo "Hello, World!" > /tmp/test-source/hello.txt
./dvx3-cli ./test-source          # Backup (creates /backup)
./dvx3-cli /backup.dvx3           # Restore to current directory
cat hello.txt                     # Should print: Hello, World!
```

---

## 🔐 Cryptographic Design

| Algorithm | Role | Notes |
|-----------|------|-------|
| **SHA-256** | Content addressing (file identification) | Pure Vala implementation with OpenSSL fallback |
| **PBKDF2-HMAC-SHA256** | Password-to-key derivation | 4096 iterations; salt stored in backup header |
| **AES-CBC / XOR Stream Cipher** | Encryption | Fallback: SHA-256 keyed counter mode ≈ CTR; OpenSSL used if available |

> 🔍 The XOR-based stream cipher is a demonstration of a pure-Vala approach. In production, we recommend the OpenSSL fallback or integrating `libsodium`.

---

## 📄 License

MIT — see [`LICENSE`](LICENSE) for details.