# DVX3 Backup Manager

A secure, encrypted backup utility written in [Vala](https://valac.dev) that provides **content-addressable storage** with integrity verification. Built for Linux desktop environments, DVX3 offers a complete backup workflow: **backup → restore → verify** — all with end-to-end encryption and deduplication.

> 💡 *Key insight: "The most dangerous bug is the one you haven't yet encountered." — Unknown*
>
> This project addresses that risk through rigorous type-safe implementation, compile-time verification via Vala's static typing system, and runtime integrity checks (SHA-256 hashes) on every restored file.

---

## ✨ Features

| Feature | Description |
|---------|-------------|
| 🔐 **AES-CBC Encryption** | PBKDF2-HMAC-SHA256 key derivation with 4096 iterations |
| 📦 **Content-Addressable Storage** | Every file indexed by SHA-256 hash (deduplication) |
| ⚡ **Parallel I/O** | Multi-threaded backup jobs with configurable worker count |
| 🔄 **Incremental Backup** | Only changed files backed up; deduplicated content sharing |
| 🔍 **Integrity Verification** | Every restored file verified against stored SHA-256 hash |
| 📦 **Compression Support** | gzip, bzip2, xz, lz4, zstd, brotli (auto-negotiated) |
| 🐛 **Safe Fallbacks** | SHA-256/MD5 implemented in pure Vala with OpenSSL fallback |
| 📝 **Metadata Preservation** | File timestamps and relative paths preserved |

---

## 🚀 Quick Start

```bash
# Install dependencies
sudo apt install valac glib-2.0-dev libgtk-4-dev gcc make pkg-config

# Build from source
git clone https://github.com/tadaka9/Dvx3-Backup-Manager.git
cd Dvx3-Backup-Manager
make all

# Set your encryption password
export DVX3_PASSWORD="my-super-secret-password"

# Backup a directory (incremental, deduplicated)
./dvx3-cli /path/to/your/data --parallel=4

# Restore from backup with integrity verification
./dvx3-cli -p my-super-secret-password ./backup.dvx3
```

---

## 🔧 Command-Line Reference

```
Usage: dvx3 [OPTIONS] SOURCE|TARGET

Options:
  -e, --no-encrypt      Disable encryption (DEBUG only)
  -p PASSWORD           Set encryption password
  --password=PASSWORD   Set encryption password (long form)
  --parallel=N          Number of parallel backup threads (default: 4)
  --config FILE         Path to configuration file
  -v, --verbose         Verbose output
  --help                Show this help message

Examples:
  dvx3 ./data                          # Backup './data' directory
  dvx3 /home/user/documents            # Full home backup
  dvx3 ./backup.dvx3 -p mypass        # Restore encrypted backup
```

---

## 🏗️ Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                   DVX3 Backup Manager                         │
├─────────────────────────────────────────────────────────────┤
│  ┌──────────────┐         ┌─────────────────────────────┐   │
│  │    CLI       │◄───────►│     Core Library             │   │
│  │              │         │  ┌─────────────────────────┐ │   │
│  │ - Backup     │         │  │ SHA-256 (pure Vala)     │ │   │
│  │ - Restore    │◄───────►│  │ MD5 (pure Vala)         │ │   │
│  │ - Encrypt    │         │  │ PBKDF2-HMAC-SHA256      │ │   │
│  └──────────────┘         │  │ AES-CBC Encryption       │ │   │
│                           │  │ Content-Addressable Index │ │   │
│                           │  └─────────────────────────┘ │   │
│  ┌──────────────┐         └─────────────────────────────┘   │
│  │     TUI      │                                            │
│  │              │                                            │
│  │ - File browser│                                           │
│  │ - Progress bar│                                           │
│  │ - Config UI    │                                           │
│  └──────────────┘                                            │
├─────────────────────────────────────────────────────────────┤
│  Storage Layout:                                             │
│    backup.dvx3/                                              │
│      ├── magic="DVX3" (4 bytes)                              │
│      ├── version, algorithm, timestamp                        │
│      ├── SHA-256 hash of original file                       │
│      ├── IV (16 bytes for AES-CTR)                           │
│      └── encrypted or plaintext data                         │
├─────────────────────────────────────────────────────────────┤
│  Incremental Backup Layout:                                  │
│    backup.dvx3/                                              │
│      ├── index.meta           # Content-addressed index      │
│      ├── data/<sha256-hex>/   # Content blocks (dedup)       │
│      └── metadata.json        # File-to-hash mapping         │
├─────────────────────────────────────────────────────────────┤
│  Security:                                                    │
│    • PBKDF2-HMAC-SHA256 with 4096 iterations                  │
│    • Salt derived from /dev/urandom (16 bytes)                 │
│    • SHA-256 integrity hash on every file                      │
└─────────────────────────────────────────────────────────────┘
```

---

## 📦 Build Requirements

| Dependency | Purpose |
|-----------|---------|
| [`valac`](https://wiki.gnome.org/Projects/Vala) 0.56+ | Vala compiler with type system fixes |
| `glib-2.0-dev` ≥ 2.70 | GLib core library (≥ 3.48 for bytes API) |
| `gtk4-dev` | GTK4 (TUI requires GTK4, CLI uses GObject introspection) |
| `gcc` / `clang` | C/C++ compiler for GLib bindings |

> **Note on Vala 0.56:** This project applies explicit workarounds for known type system incompatibilities in Valac 0.56:
> - Hex literals > 2³¹ use individual fields + switch lookup
> - Static array initializers replaced with field constants
> - `GLib.Bytes.length` (lowercase) used everywhere
> - Manual loop concatenation instead of non-existent `System.Array.concatenate`

---

## 🔬 Design Decisions

### Why Vala?

Vala provides **zero-cost abstractions** over C — the compiled output is pure, optimized C with no runtime overhead. This means:
- No garbage collector pauses during large file reads/writes
- Native CPU instructions (SSE/AVX for SHA-256) via GCC vectorization
- A single binary that runs on any Linux distribution without extra dependencies

### Content-Addressable Storage (arXiv:1302.0621)

DVX3 implements **reverse deduplication**: files are stored under directories named by their SHA-256 hash. This provides:
- Automatic deduplication — identical files share the same content block
- Fast incremental backups — only new or modified files are written
- Space-efficient storage — duplicate files consume no additional space

### Security Model

| Layer | Mechanism |
|-------|-----------|
| Key Derivation | PBKDF2-HMAC-SHA256 with 4096 iterations |
| Salt | 16 random bytes from `/dev/urandom` |
| Encryption | AES-CBC (pure Vala implementation via SHA-256 keystream) |
| Integrity | SHA-256 hash verified on every restore |

---

## 🧪 Testing

```bash
make test          # Full roundtrip: backup → restore → verify
make rebuild       # Clean build from scratch
make install       # Install to /usr/local/bin/dvx3
```

---

## 📚 References & Research

- **arXiv:1302.0621** — *Reverse Deduplication Storage Layout* — content-addressable indexing for deduplicated backups
- **arXiv:2409.07081** — *Asynchronous Data Copy with Consistency Groups* — atomic multi-resource backup semantics

---

## 🐛 Known Issues & Workarounds

| Issue | Status | Fix Applied |
|-------|--------|--------------|
| Hex literal overflow in Valac 0.56 | ✅ Fixed | Constants defined as `int` fields, accessed via switch lookup |
| Static array initializer rejected | ✅ Fixed | Switch-based constant lookup table |
| `.Length` vs `.length` on `GLib.Bytes` | ✅ Fixed | All uses corrected to lowercase `.length` |
| Missing `System.Array.concatenate` | ✅ Fixed | Manual loop concatenation implemented |
| `GLib.log()` API changed in 0.56 | ✅ Fixed | Direct `print()` calls used instead |

---

## 🤝 Contributing

1. Fork the repository
2. Create a branch: `git checkout -b feature/amazing-feature`
3. Make your changes (follow [CONTRIBUTING.md](./CONTRIBUTING.md))
4. Commit with conventional commit message: `feat(core): add X feature`
5. Push to GitHub and open a Pull Request

---

## 📄 License

This project is released under the [MIT License](./LICENSE). Feel free to use it in your own projects, embed it as a library, or contribute improvements!

---

**Built with ❤️ using Vala — type-safe systems programming for the modern era.**