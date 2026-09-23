# Dvx3 Backup Manager - Qt6 Desktop GUI

A modern, beautiful, and fully-functional desktop application for secure backup management.

## 📦 Quick Start

### Prerequisites

**Linux:**
```bash
sudo apt install qt6-base-dev cmake libsodium-dev
```

**macOS:**
```bash
brew install qt@6 cmake zip dos2unix
export QTDIR="$(brew --prefix qt@6)"
```

**Windows (MSYS2):**
```bash
pacman -S mingw-w64-x86_64-qt6-base mingw-w64-x86_64-cmake mingw-w64-x86_64-librariesodium
```

### Build Instructions

```bash
cd /home/dvx3/Documenti/Programming/Vala/Dvx3-Backup-Manager
./build_all.sh
```

This will build both the CLI tool and Qt6 GUI application.

### Run Application

**Direct Execution:**
```bash
./build-gui/qt/qtdesktop/backup-manager
```

**System Tray:** Double-click anywhere in the tray icon to restore window.

## 🎯 Features

- **🎉 Welcome Tab:** Introduction with feature showcase
- **📦 Create Backup:** Three-step wizard for encrypted backups
- **🔄 Restore:** Decryption and file extraction
- **📊 Dashboard:** Recent operations history
- **⚙️ Settings:** Configuration and preferences

## 🔐 Security

- AES-256 encryption via libsodium SecretBox
- Argon2id key derivation
- SHA-256 integrity verification (optional, enabled by default)

## 📖 Documentation

- `docs/session_checkpoints/CHECKPOINT_PHASE3_START.md` - Detailed implementation guide
- `docs/session_checkpoints/PHASE3_COMPLETION_REPORT.md` - Complete feature list
- See main repository README for usage examples

## 🐛 Troubleshooting

**"Cannot find cli_backup_manager"**
```bash
./build_all.sh  # Build CLI first
```

**"Qt6 not found"**
```bash
sudo apt install qt6-base-dev  # Or use GTK4 fallback if available
```

## 📝 License

Dvx3 Backup Manager is open source software. See LICENSE for details.
