# DVX3 Backup Manager

A secure, encrypted backup utility written in [Vala](https://valac.dev) that provides content-addressable storage with integrity verification. Built for Linux desktop environments, DVX3 offers a complete backup workflow: **backup → restore → verify** — all with end-to-end encryption and compression support.

> 💡 *Key insight: "The most dangerous bug is the one you haven't yet encountered." — Unknown.*
>
> This project addresses that risk through rigorous type-safe implementation, compile-time verification via Vala's static typing system, and runtime integrity checks (SHA-256 hashes) on every restored file.

---

## ✨ Features

| Feature | Description |
|---------|-------------|
| 🔐 **AES-CBC Encryption** | PBKDF2-HMAC-SHA256 key derivation with 4096 iterations |
| 📦 **Content-Addressable Storage** | Every file is indexed by its SHA-256 hash (deduplication ready) |
| ⚡ **Parallel I/O** | Multi-threaded backup jobs with configurable worker count |
| 🔄 **Incremental Backup** | Only changed files are backed up on subsequent runs |
| 🔍 **Integrity Verification** | Every restored file is verified against its stored hash before writing |
| 📦 **Compression Support** | gzip, bzip2, xz, lz4, zstd, brotli (auto-negotiated) |
| 🐛 **Safe Fallbacks** | SHA-256/MD5 implemented in pure Vala with fallback for cryptographic failures |
| 📝 **Metadata Preservation** | File timestamps, permissions, and relative paths preserved |

---

## 🚀 Quick Start

```bash
# Install dependencies
sudo apt install valac glib-2.0-dev libgtk-4-dev gcc make

# Build from source
git clone https://github.com/dvx3/Dvx3-Backup-Manager.git
cd Dvx3-Backup-Manager
make all

# Set your encryption password (stores in ~/.config/dvx3/password)
export DVX3_PASSWORD="my-super-secret-password"

# Backup a directory
./dvx3-cli /path/to/your/data

# Restore from backup
./dvx3-cli -p my-super-secret-password ./backup.dvx3
```

---

## 🔧 Command-Line Reference

```
Usage: dvx3 [OPTIONS] SOURCE|TARGET

Options:
  -e, --no-encrypt    Disable encryption (DEBUG only)
  -p PASSWORD         Set encryption password
  --password=PASSWORD Set encryption password (long form)
  --parallel=N        Number of parallel backup threads (default: 4)
  --config FILE       Path to configuration file
  -v, --verbose       Verbose output
  --help              Show this help message

Examples:
  dvx3 ./data                          # Backup './data' directory
  dvx3 ./backup.dvx3 -p mypass         # Restore encrypted backup with password
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
│  │ - Decrypt    │         │  │ AES-CBC Encryption       │ │   │
│  └──────────────┘         │  │ Content-Addressable Index│ │   │
│                           │  │ Integrity Verification    │ │   │
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
│      ├── SHA-256 hash of original file                        │
│      ├── IV (16 bytes for AES-CTR)                            │
│      └── encrypted or plaintext data                          │
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
| [`valac`](https://wiki.gnome.org/Projects/Vala) 0.56+ | Vala compiler with type system fixes applied |
| `glib-2.0-dev` ≥ 2.70 | GLib core library (≥ 3.48 for bytes API) |
| `gtk4-dev` | GTK4 (TUI requires GTK4, CLI uses GTK's GObject introspection) |
| `gcc` / `clang` | C/C++ compiler for GLib bindings |

> **Note on Vala 0.56:** This project applies explicit workarounds for known type system incompatibilities in Valac 0.56 (hex literal overflow, array initializer restrictions, `.length` vs `.Length`). See [`vala/core/dvx3.vala`](./vala/core/dvx3.vala) for the full implementation of these fixes.

---

## 🔬 Design Decisions

### Why Vala?

Vala provides **zero-cost abstractions** over C — the compiled output is pure, optimized C with no runtime overhead. This means:
- No garbage collector pauses during large file reads/writes
- Native CPU instructions (SSE/AVX for SHA-256) via GCC vectorization
- A single binary that runs on any Linux distribution without extra dependencies

### Why not use existing backup tools?

| Tool | Limitation | DVX3 Solution |
|------|-------------|---------------|
| `rsync` | No encryption, no integrity hash per-file | ✅ AES + SHA-256 per file |
| `tar` / `cpio` | Plain text archives, no deduplication | ✅ Content-addressable storage |
| `borgbackup` | Requires Python, complex config | ✅ Single binary, zero-config after setup |

---

## 📚 References & Research

- **arXiv:1302.0621** — *Reverse Deduplication Storage Layout* — content-addressable indexing for deduplicated backups
- **arXiv:2409.07081** — *Asynchronous Data Copy with Consistency Groups* — atomic multi-resource backup semantics

---

## 🧪 Testing

```bash
make test        # Full roundtrip: backup → restore → SHA-256 verify
make rebuild     # Clean build from scratch
make install     # Install to /usr/local/bin/dvx3
```

---

## 🔒 Security Considerations

- **Key derivation:** PBKDF2-HMAC-SHA256 with 4096 iterations — chosen to resist brute-force attacks on password-based encryption.
- **Salt:** 16 random bytes from `/dev/urandom` ensures unique keys even for repeated passwords.
- **Integrity verification:** Every restored file is hashed and compared against its stored SHA-256 before being written — corruption or tampering is detected immediately.
- **Fallback crypto:** If the system's OpenSSL-backed checksum fails, a pure-Vala fallback implementation (no external dependencies) is used automatically.

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
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Make your changes (add tests!)
4. Commit with conventional commit message: `feat: add amazing feature`
5. Push to GitHub and open a Pull Request

---

## 📄 License

This project is released under the [MIT License](./LICENSE). Feel free to use it in your own projects, embed it as a library, or contribute improvements!

---

**Built with ❤️ using Vala — type-safe systems programming for the modern era.**