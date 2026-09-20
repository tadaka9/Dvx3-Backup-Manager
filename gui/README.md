# Dvx3 Backup Manager - GUI Implementation

## Build Strategy

This project supports two GUI implementations based on platform:

### Linux (GTK4)
- Uses Vala-GTK bindings for native GTK4 application
- Built with `./build_all.sh`
- Requires: gir1.2-gtk-4.0, libgtk-4-dev, gio-unix-2.0

### macOS/Windows (Qt6)
- Uses CMake + Qt6 for native desktop application
- Built with `./build_qt6_gui.sh`
- Requires: Qt@6 (via Homebrew on macOS or MSYS2 on Windows)

---

## Platform-Specific Instructions

### Linux

```bash
# Install dependencies
sudo apt install gir1.2-gtk-4.0 libgtk-4-dev gio-unix-2.0 pkg-config zip dos2unix

# Build CLI and GUI
./build_all.sh

# Test GUI
./dvx3-backup-manager
```

### macOS

```bash
# Install Qt6 and dependencies
brew install qt@6 cmake zip dos2unix

# Set environment variables
export QTDIR="$(brew --prefix qt@6)"
export PATH="$QTDIR/bin:$PATH"

# Build GUI with Qt6
./build_qt6_gui.sh

# Test GUI
./gui/qt-build/dvx3-backup-manager
```

### Windows (WSL/MSYS2)

```bash
# Install MSYS2 toolchain
pacman -S mingw-w64-x86_64-qt6-base mingw-w64-x86_64-cmake \
    mingw-w64-x86_64-glib mingw-w64-x86_64-json-glib \
    mingw-w64-x86_64-libsodium pkgconf vala dos2unix zip

# Build CLI first (required)
./build_all.sh

# Build Qt6 GUI
./build_qt6_gui.sh
```

---

## Features

The Qt6 GUI provides:

- **Create Backup**: Select source directory, set password, encrypt to .dvx3 archive
- **Restore**: Select backup file, choose destination, decrypt and extract files
- **Progress Monitoring**: Real-time progress bar for encryption/decryption operations
- **Error Handling**: User-friendly error messages with retry options
- **Cross-Platform**: Native look and feel on each platform

---

## Architecture

### CLI Backend
The GUI calls the CLI executable (`cli_backup_manager`) via `QProcess`:
- Encryption: `cli_backup_manager encrypt <source> -p <password> -o <output>`
- Decryption: `cli_backup_manager decrypt <archive> -p <password> -o <destination>`

### GUI Frontend (Qt6)
- QMainWindow with toolbar for primary actions
- Progress bar showing operation status
- Status bar displaying current message
- File dialogs for source/destination selection

---

## Project Structure

```
gui/
├── qt/                          # Qt6 build directory
│   ├── backup-manager-qtdesktop.cpp  # Main Qt application
│   ├── CMakeLists.txt           # CMake configuration
│   └── qrc_resources.qrc        # Qt resource file
├── src/                        # GTK4 implementation (Linux)
│   ├── dashboard.vala          # Vala-GTK bindings
│   └── dashboard.ui            # UI layout
├── README.md                   # This file
└── build_qt6_gui.sh           # Qt6 build script for macOS/Windows
```

---

## Troubleshooting

### Qt6 Not Found (macOS)
```bash
brew install qt@6
export QTDIR="$(brew --prefix qt@6)"
```

### MSYS2 Package Issues (Windows)
```bash
pacman -Syu  # Update package database
pacman -S --needed mingw-w64-x86_64-qt6-base
```

---

## License

Same as the rest of Dvx3 Backup Manager.
