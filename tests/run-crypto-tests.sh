#!/bin/bash
# Run cryptographic test suite for Dvx3

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

echo "═══════════════════════════════════════════════════════"
echo "  Dvx3 Cryptographic Test Suite Runner"
echo "═══════════════════════════════════════════════════════"
echo ""

# Check for valac compiler
if ! command -v valac &> /dev/null; then
    echo "❌ Error: valac not found. Please install Vala compiler."
    echo "   Install with: sudo apt install valac"
    exit 1
fi

echo "✓ valac found: $(valac --version)"
echo ""

# Check for libsodium
if ! pkg-config --exists libsodium; then
    echo "❌ Error: libsodium not found. Please install libsodium-dev."
    echo "   Install with: sudo apt install libsodium-dev"
    exit 1
fi

echo "✓ libsodium found: $(pkg-config --modversion libsodium)"
echo ""

# Compile the test suite
echo "Compiling cryptographic-tests.vala..."
cd "$PROJECT_ROOT"

valac \
    -g \
    -c \
    tests/cryptographic-tests.vala \
    -I/usr/include/glib-2.0 \
    -I/usr/lib/x86_64-linux-gnu/glib-2.0/include \
    -I/usr/include/json-glib-1.0 \
    -I/usr/lib/x86_64-linux-gnu/json-glib-1.0/include \
    -lsodium \
    -o tests/cryptographic-tests

if [ $? -eq 0 ]; then
    echo "✓ Compilation successful"
else
    echo "❌ Compilation failed"
    exit 1
fi

echo ""
echo "Running cryptographic tests..."
echo ""

# Run the tests
"$PROJECT_ROOT/tests/cryptographic-tests"

exit_code=$?

if [ $exit_code -eq 0 ]; then
    echo ""
    echo "═══════════════════════════════════════════════════════"
    echo "  All cryptographic tests passed!"
    echo "═══════════════════════════════════════════════════════"
else
    echo ""
    echo "═══════════════════════════════════════════════════════"
    echo "  Some tests failed. Check output above for details."
    echo "═══════════════════════════════════════════════════════"
fi

exit $exit_code
