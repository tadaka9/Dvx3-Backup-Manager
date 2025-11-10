#!/bin/bash
# install.sh - Install backup-manager system-wide

set -e

# Configuration
PREFIX="${PREFIX:-/usr/local}"
BINDIR="$PREFIX/bin"
LIBDIR="$PREFIX/lib"
DATADIR="$PREFIX/share/backup-manager"
MANDIR="$PREFIX/share/man/man1"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo "╔════════════════════════════════════════════╗"
echo "║   Backup Manager Installation Script      ║"
echo "╚════════════════════════════════════════════╝"
echo ""

# Check if running as root for system-wide installation
if [ "$PREFIX" = "/usr" ] || [ "$PREFIX" = "/usr/local" ]; then
    if [ "$EUID" -ne 0 ]; then
        echo -e "${YELLOW}Warning: Installing to $PREFIX requires root privileges.${NC}"
        echo "Run with: sudo ./install.sh"
        echo "Or install to your home directory: PREFIX=~/.local ./install.sh"
        exit 1
    fi
fi

# Build if needed
if [ ! -f "./backup-manager" ]; then
    echo "Building backup-manager..."
    ./build_backup_manager.sh
    echo ""
fi

# Create directories
echo "Creating installation directories..."
mkdir -p "$BINDIR"
mkdir -p "$DATADIR"
mkdir -p "$MANDIR"

# Install binary
echo "Installing backup-manager to $BINDIR..."
install -m 755 backup-manager "$BINDIR/backup-manager"

# Install library (for standalone C++ programs)
if [ -f "libdvx3.o" ]; then
    mkdir -p "$LIBDIR"
    echo "Installing libdvx3.o to $LIBDIR..."
    install -m 644 libdvx3.o "$LIBDIR/libdvx3.o"
fi

# Install headers (for development)
if [ -f "dvx3.h" ]; then
    mkdir -p "$PREFIX/include"
    echo "Installing headers to $PREFIX/include..."
    install -m 644 dvx3.h "$PREFIX/include/dvx3.h"
    install -m 644 dvx3.hpp "$PREFIX/include/dvx3.hpp"
    install -m 644 backup-manager.hpp "$PREFIX/include/backup-manager.hpp"
fi

# Install documentation
echo "Installing documentation to $DATADIR..."
install -m 644 BACKUP_MANAGER_GUIDE.md "$DATADIR/GUIDE.md"
if [ -f "CPP_USAGE.md" ]; then
    install -m 644 CPP_USAGE.md "$DATADIR/CPP_USAGE.md"
fi

# Create man page
echo "Creating man page..."
cat > "$MANDIR/backup-manager.1" << 'EOF'
.TH BACKUP-MANAGER 1 "November 2025" "1.0" "Backup Manager Manual"
.SH NAME
backup-manager \- encrypted backup management system
.SH SYNOPSIS
.B backup-manager
[\fICOMMAND\fR] [\fIOPTIONS\fR]
.SH DESCRIPTION
.B backup-manager
is a comprehensive backup management system using dvx3 encryption library.
It provides encrypted, compressed backups with retention policies and history tracking.
.SH COMMANDS
.TP
.B list
List all configured backup jobs
.TP
.B status
Show status of all backup jobs
.TP
.B history
View backup history
.TP
.B run <job>
Run a specific backup job
.TP
.B cleanup
Remove old backups according to retention policies
.SH INTERACTIVE MODE
Run without arguments to enter interactive menu mode with full job management capabilities.
.SH FILES
.TP
.I ~/.config/backup-manager/backup-manager.conf
User configuration file storing backup jobs
.TP
.I ~/.config/backup-manager/backup-history.log
History log of all backup operations
.SH ENCRYPTION
Backups are encrypted using Argon2id key derivation and XSalsa20-Poly1305 authenticated encryption.
Archives are compressed with zstd before encryption.
.SH EXAMPLES
.TP
Interactive mode:
.B backup-manager
.TP
Run backup job:
.B backup-manager run "Documents"
.TP
View all jobs:
.B backup-manager list
.SH AUTHOR
Written using the dvx3 encryption library.
.SH SEE ALSO
Full documentation at:
.I /usr/local/share/backup-manager/GUIDE.md
EOF

# Update config directory to user's home
echo "Creating default config directory template..."
cat > "$DATADIR/README" << 'EOF'
Backup Manager Configuration

The backup manager stores its configuration in:
  ~/.config/backup-manager/

Files:
  backup-manager.conf  - Job configurations
  backup-history.log   - Backup history

These files are created automatically on first run.

For detailed documentation, see GUIDE.md in this directory.
EOF

echo ""
echo -e "${GREEN}✓ Installation complete!${NC}"
echo ""
echo "Installation summary:"
echo "  Binary:        $BINDIR/backup-manager"
echo "  Documentation: $DATADIR/"
echo "  Man page:      $MANDIR/backup-manager.1"
if [ -f "$LIBDIR/libdvx3.o" ]; then
    echo "  Library:       $LIBDIR/libdvx3.o"
    echo "  Headers:       $PREFIX/include/dvx3.{h,hpp}"
fi
echo ""
echo "Usage:"
echo "  backup-manager              - Interactive mode"
echo "  backup-manager list         - List backup jobs"
echo "  backup-manager run <job>    - Run backup"
echo "  man backup-manager          - View manual"
echo ""
echo "Configuration will be stored in: ~/.config/backup-manager/"
echo ""
