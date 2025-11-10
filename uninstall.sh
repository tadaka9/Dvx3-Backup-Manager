#!/bin/bash
# uninstall.sh - Uninstall backup-manager from system

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
NC='\033[0m'

echo "╔════════════════════════════════════════════╗"
echo "║   Backup Manager Uninstall Script         ║"
echo "╚════════════════════════════════════════════╝"
echo ""

# Check if running as root for system-wide uninstallation
if [ "$PREFIX" = "/usr" ] || [ "$PREFIX" = "/usr/local" ]; then
    if [ "$EUID" -ne 0 ]; then
        echo -e "${YELLOW}Warning: Uninstalling from $PREFIX requires root privileges.${NC}"
        echo "Run with: sudo ./uninstall.sh"
        exit 1
    fi
fi

echo "Removing backup-manager from $PREFIX..."
echo ""

# Remove binary
if [ -f "$BINDIR/backup-manager" ]; then
    echo "Removing $BINDIR/backup-manager..."
    rm -f "$BINDIR/backup-manager"
fi

# Remove library
if [ -f "$LIBDIR/libdvx3.o" ]; then
    echo "Removing $LIBDIR/libdvx3.o..."
    rm -f "$LIBDIR/libdvx3.o"
fi

# Remove headers
if [ -f "$PREFIX/include/dvx3.h" ]; then
    echo "Removing headers..."
    rm -f "$PREFIX/include/dvx3.h"
    rm -f "$PREFIX/include/dvx3.hpp"
    rm -f "$PREFIX/include/backup-manager.hpp"
fi

# Remove documentation
if [ -d "$DATADIR" ]; then
    echo "Removing documentation..."
    rm -rf "$DATADIR"
fi

# Remove man page
if [ -f "$MANDIR/backup-manager.1" ]; then
    echo "Removing man page..."
    rm -f "$MANDIR/backup-manager.1"
fi

echo ""
echo -e "${GREEN}✓ Uninstallation complete!${NC}"
echo ""
echo -e "${YELLOW}Note: User configuration files in ~/.config/backup-manager/ were not removed.${NC}"
echo "To remove them manually:"
echo "  rm -rf ~/.config/backup-manager/"
echo ""
