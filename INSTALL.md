# Backup Manager - Installation Guide

## Installation Options

### Option 1: System-wide Installation (Recommended)

Install for all users with root privileges:

```bash
sudo ./install.sh
```

This installs to `/usr/local`:
- Binary: `/usr/local/bin/backup-manager`
- Man page: `/usr/local/share/man/man1/backup-manager.1`
- Documentation: `/usr/local/share/backup-manager/`
- Headers: `/usr/local/include/dvx3.{h,hpp}`

After installation, run from anywhere:
```bash
backup-manager
man backup-manager
```

### Option 2: User Installation

Install to your home directory (no root required):

```bash
PREFIX=~/.local ./install.sh
```

Add to your PATH in `~/.bashrc` or `~/.profile`:
```bash
export PATH="$HOME/.local/bin:$PATH"
```

### Option 3: Standalone Usage

Use directly without installation:

```bash
# Build first
./build_backup_manager.sh

# Run from source directory
./backup-manager
```

Configuration files will be stored in the current directory.

## Configuration Location

When installed, configuration is stored in:
```
~/.config/backup-manager/
  ├── backup-manager.conf    # Job configurations
  └── backup-history.log     # Backup history
```

When running standalone (not installed), configuration is stored in the current directory.

## Uninstallation

To remove an installed version:

```bash
# System-wide uninstall
sudo ./uninstall.sh

# User uninstall
PREFIX=~/.local ./uninstall.sh
```

**Note:** Uninstallation does NOT remove your configuration files in `~/.config/backup-manager/`. Remove them manually if desired:
```bash
rm -rf ~/.config/backup-manager/
```

## Building from Source

Requirements:
- Vala compiler (0.56+)
- GLib 2.0
- JSON-GLib
- libsodium
- zstd
- gcc/g++ with C++17 support

### On Arch Linux:
```bash
sudo pacman -S vala glib2 json-glib libsodium zstd gcc
```

### On Debian/Ubuntu:
```bash
sudo apt-get install valac libglib2.0-dev libjson-glib-dev \
                     libsodium-dev zstd g++
```

### Build:
```bash
./build_backup_manager.sh
```

## Development Installation

For C++ development using the dvx3 library:

```bash
# Install headers and library
sudo ./install.sh

# Now you can compile your own programs
g++ myprogram.cpp -std=c++17 \
    $(pkg-config --cflags --libs glib-2.0 gio-unix-2.0 json-glib-1.0 libsodium) \
    /usr/local/lib/libdvx3.o -lstdc++fs
```

Include in your code:
```cpp
#include <dvx3.hpp>
#include <backup-manager.hpp>
```

## Automation Setup

### Systemd Timer (System-wide Installation)

Create `~/.config/systemd/user/backup-daily.service`:
```ini
[Unit]
Description=Daily Backup

[Service]
Type=oneshot
ExecStart=/usr/local/bin/backup-manager run "Documents"
```

Create `~/.config/systemd/user/backup-daily.timer`:
```ini
[Unit]
Description=Run backup daily

[Timer]
OnCalendar=daily
OnCalendar=02:00
Persistent=true

[Install]
WantedBy=timers.target
```

Enable:
```bash
systemctl --user enable --now backup-daily.timer
systemctl --user list-timers
```

### Cron (Any Installation)

Edit crontab:
```bash
crontab -e
```

Add entries:
```cron
# Daily backup at 2 AM
0 2 * * * /usr/local/bin/backup-manager run "Documents"

# Weekly cleanup on Sunday at 3 AM
0 3 * * 0 /usr/local/bin/backup-manager cleanup
```

## Verifying Installation

```bash
# Check if installed
which backup-manager

# View version
backup-manager --help 2>&1 | head -n 3

# View man page
man backup-manager

# Check config directory
ls -la ~/.config/backup-manager/
```

## Troubleshooting

**Command not found after installation:**
- Ensure `/usr/local/bin` is in your PATH
- Or add to `~/.bashrc`: `export PATH="/usr/local/bin:$PATH"`
- Then: `source ~/.bashrc`

**Permission denied:**
- System installation requires sudo
- Use user installation: `PREFIX=~/.local ./install.sh`

**Build failures:**
- Install all dependencies listed above
- Check Vala version: `valac --version`
- Ensure pkg-config can find libraries: `pkg-config --libs libsodium`

**Config directory not created:**
- The program creates it automatically on first run
- Or create manually: `mkdir -p ~/.config/backup-manager`
