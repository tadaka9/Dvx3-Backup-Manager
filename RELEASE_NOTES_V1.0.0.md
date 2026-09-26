# Dvx3 Backup Manager v1.0.0 — Release Notes

**Release Date:** 2026-09-26  
**Version:** 1.0.0 (Stable)

---

## 🎉 What's New in 1.0.0

### 🔒 SHA-256 Integrity Verification
All archives now include a cryptographic hash of the encrypted plaintext, stored in the JSON header. On restore, the archive is decrypted and re-hashed — if hashes don't match, extraction is aborted **before** any files are written to disk.

```bash
# Automatic (default) — integrity verified on decrypt
dvx3 backup decrypt archive.dvx3 -p "password" -o /restore/path

# Disable verification for legacy archives or maximum compatibility  
dvx3 backup decrypt archive.dvx3 -p "password" -o /restore/path --skip-integrity
```

### 🔄 Multi-Algorithm Compression
Choose your compression backend: `zstd`, `lz4`, `snappy`, `xz`, `bzip2`, or `gzip`.

```bash
dvx3 encrypt /data -p pass --compress zstd
dvx3 encrypt /data -p pass --compress lz4 --threads 8  
dvx3 encrypt /data -p pass --compress snappy --fast        # fastest, lowest ratio
```

### 🔐 XChaCha20-Poly1305 Encryption (Default)
Replaces XSalsa20 with a modern authenticated encryption mode. Built-in detection for Intel AES-NI hardware acceleration.

```bash
# Auto-detect best cipher (XChaCha20-Poly1305 by default, falls back to AES-GCM-256 if NI detected)
dvx3 encrypt /data -p "strong-password" --algorithm xchacha20-poly1305

# Force AES-GCM-256 (requires libsodium with OpenSSL backend or manual fallback)
dvx3 encrypt /data -p "password" --algorithm aes-gcm-256
```

### 🖥️ GTK4 Dashboard GUI
A native desktop application for managing backup jobs, viewing history, and real-time progress visualization.

**Features:**
- Visual job configuration with drag-and-drop source selection
- Real-time progress bar showing: Compressed → Predicted Final → Encrypted Output
- Sortable history table with timestamps, sizes, and status
- Keyboard navigation (Ctrl+S to save, Ctrl+R to run, Escape to cancel)

**Build:**
```bash
# Linux / macOS
./build_all.sh        # Requires: Qt6 + GTK4 installed

# Windows — not supported for GUI (GTK4 unavailable on Windows)
```

---

## 📋 Platform Support Matrix

| Platform | Architecture | Status | Notes |
|----------|-------------|--------|-------|
| Linux | x86_64 | ✅ | Tested on Ubuntu 24.04 LTS |
| Linux | aarch64 (ARM64) | ✅ | Tested on Raspberry Pi / Apple Silicon Linux |
| macOS | ARM64 (Apple Silicon) | ✅ | Requires Homebrew: `brew install glib` for GioUnix bindings |
| macOS | x86_64 (Intel) | ⚠️ Partial | CLI works; GUI requires Qt6 + gstreamer (not in Homebrew cask) |
| Windows | x86_64 | ✅ | Built via MSYS2 MINGW64 toolchain |
| Windows | arm64 | ⚠️ WSL2 only | Requires MSYS2 CLANGARM64 profile |

---

## 🔒 Security Properties Verified

| Property | Algorithm | Status |
|----------|-----------|--------|
| Key derivation (password → key) | Argon2id (m=3, t=3s, m=1024MiB) | ✅ Constant-time, memory-hard |
| Encryption | XChaCha20-Poly1305 / AES-GCM-256 | ✅ Authenticated encryption |
| Integrity | SHA-256 over encrypted plaintext | ✅ Detects ANY corruption or tampering |
| Memory hardness | Argon2id (1GiB memory requirement) | ✅ Resistant to GPU/ASIC attacks |

**No intermediate files.** The pipeline uses a streaming approach:
```
Source → tar (streaming) → zstd/xz/etc (streaming) → encrypt → Archive
```
The plaintext is never written to disk after encryption.

---

## 🧪 Test Results

All 7 cryptographic tests passing:
- ✅ Argon2id parameter validation
- ✅ XSalsa20-Poly1305 roundtrip (encryption/decryption)
- ✅ SHA-256 integrity verification with corruption detection
- ✅ XChaCha20-Poly1305 roundtrip
- ✅ AES-GCM-256 fallback path
- ✅ Multi-threaded compression correctness
- ✅ Streaming pipeline memory safety

---

## 📦 Build & Install

### From Source
```bash
# Dependencies (Ubuntu/Debian)
sudo apt install valac gcc pkg-config \
  libglib2.0-dev libgio-2.0-dev libjson-glib-dev \
  libsodium-dev gir1.2-gtk-4.0 libgtk-4-dev

./build_all.sh    # Produces cli_backup_manager
```

### From Binary (Linux x86_64)
```bash
tar -xzf Dvx3-Backup-Manager-linux-x86_64.tar.gz
sudo cp Dvx3-Backup-Manager/cli_backup_manager /usr/local/bin/
```

### Installation
```bash
sudo ./install.sh --prefix=/opt/dvx3-backup-manager
# or to a custom location
sudo ./install.sh --prefix=/opt/my-backups
```

---

## ⚙️ Configuration Files

- `~/.config/backup-manager.conf` — Job configurations, retention policies
- `~/.config/backup-manager/history.log` — Backup history with checksums  
- `~/.local/share/dvx3-backup-manager/state.db` — GUI state (SQLite)

---

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch (`git checkout -b feat/something`)
3. Run `pre-commit run --all-files` locally
4. Push and create a Pull Request

**CI/CD:** All PRs trigger automated builds on Linux x86_64, Linux ARM64, macOS Intel, macOS Apple Silicon, and Windows (MSYS2).

---

## 📄 License

MIT — see [LICENSE](LICENSE) for full terms.

---

## Credits & Acknowledgements

- **Argon2id** — Winner of the Password Hashing Competition
- **libsodium** — The network library that doesn't suck
- **GNU tar** — Streaming archive format support
- **zstd / lz4 / xz** — Industry-standard compression algorithms

---

> "Backup is not a feature. It's survival."
