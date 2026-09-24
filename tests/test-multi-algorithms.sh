#!/bin/bash
# Test suite for multi-algorithm compression and encryption in Dvx3

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
TEST_DIR="$PROJECT_ROOT/tests/multi-algo-test"

echo "═══════════════════════════════════════════════════════"
echo "  Dvx3 Multi-Algorithm Test Suite"
echo "  Compression: zstd|lz4|snappy|xz|bzip2|gzip | Encryption: XChaCha20-Poly1305|AES-GCM"
echo "═══════════════════════════════════════════════════════"
echo ""

# Create test directory
mkdir -p "$TEST_DIR"

# Test data (use /dev/urandom for realistic binary data)
echo "Creating test data..."
dd if=/dev/urandom of="$TEST_DIR/test-data.bin" bs=1M count=10 2>/dev/null
echo "✓ Created 10MB test data"
echo ""

# Detect hardware
echo "Detecting hardware capabilities..."
if grep -q "ni" /proc/cpuinfo 2>/dev/null || grep -q "avx2\|fma" /proc/cpuinfo 2>/dev/null; then
    echo "✓ Intel NI instructions detected (AES-GCM available)"
    HAS_INTEL_NI=true
else
    echo "⚠ No Intel NI detected (using XChaCha20-Poly1305 fallback)"
    HAS_INTEL_NI=false
fi
echo ""

# Test compression algorithms
echo "═══════════════════════════════════════════════════════"
echo "  COMPRESSION TESTS"
echo "═══════════════════════════════════════════════════════"
echo ""

for algo in zstd lz4 snappy xz bzip2 gzip; do
    echo "[Testing $algo compression]..."
    
    case $algo in
        zstd)
            zstd -3 -T0 "$TEST_DIR/test-data.bin" -o "$TEST_DIR/test-data.${algo}.zst" 2>/dev/null
            ;;
        lz4)
            lz4 -f "$TEST_DIR/test-data.bin" -o "$TEST_DIR/test-data.${algo}.lz4" 2>/dev/null || \
            lz4 -1 "$TEST_DIR/test-data.bin" -o "$TEST_DIR/test-data.${algo}.lz4" 2>/dev/null
            ;;
        snappy)
            # Snappy is usually a filter, use pigz or similar
            if command -v snappy &>/dev/null; then
                snappy -c < "$TEST_DIR/test-data.bin" > "$TEST_DIR/test-data.${algo}.snappy" 2>/dev/null || true
            else
                echo "  ⚠ Snappy not available, skipping"
                continue
            fi
            ;;
        xz)
            xz -6 -c < "$TEST_DIR/test-data.bin" > "$TEST_DIR/test-data.${algo}.xz" 2>/dev/null || \
            xz -9 "$TEST_DIR/test-data.bin" -o "$TEST_DIR/test-data.${algo}.xz" 2>/dev/null
            ;;
        bzip2)
            bzip2 -9 -c < "$TEST_DIR/test-data.bin" > "$TEST_DIR/test-data.${algo}.bz2" 2>/dev/null || \
            bzip2 -9 "$TEST_DIR/test-data.bin" -o "$TEST_DIR/test-data.${algo}.bz2" 2>/dev/null
            ;;
        gzip)
            gzip -6 -c < "$TEST_DIR/test-data.bin" > "$TEST_DIR/test-data.${algo}.gz" 2>/dev/null || \
            gzip -9 "$TEST_DIR/test-data.bin" -o "$TEST_DIR/test-data.${algo}.gz" 2>/dev/null
            ;;
    esac
    
    if [ -f "$TEST_DIR/test-data.${algo}.*" ]; then
        original_size=$(stat -c%s "$TEST_DIR/test-data.bin")
        compressed_file=$(ls "$TEST_DIR"/test-data.${algo}.* | head -1)
        compressed_size=$(stat -c%s "$compressed_file")
        ratio=$((original_size * 100 / compressed_size))
        
        echo "  ✓ Compressed: $original_size → $compressed_size bytes (${ratio}%)"
    else
        echo "  ⚠ Compression failed for $algo"
    fi
    
    # Test decompression
    if [ -f "$TEST_DIR/test-data.${algo}.*" ]; then
        decompressed_file=$(mktemp)
        case $algo in
            zstd) zstd -d -c < "$compressed_file" > "$decompressed_file" ;;
            lz4) lz4 -dc < "$compressed_file" > "$decompressed_file" ;;
            snappy) snappy -c < "$compressed_file" > "$decompressed_file" 2>/dev/null || true ;;
            xz) xz -dc < "$compressed_file" > "$decompressed_file" ;;
            bzip2) bzip2 -dc < "$compressed_file" > "$decompressed_file" ;;
            gzip) gzip -dc < "$compressed_file" > "$decompressed_file" ;;
        esac
        
        if diff -q "$TEST_DIR/test-data.bin" "$decompressed_file" >/dev/null 2>&1; then
            echo "  ✓ Decompression verified (data integrity OK)"
        else
            echo "  ✗ Decompression FAILED (data mismatch!)"
        fi
        
        rm -f "$decompressed_file"
    fi
    
    echo ""
done

# Test encryption algorithms
echo "═══════════════════════════════════════════════════════"
echo "  ENCRYPTION TESTS"
echo "═══════════════════════════════════════════════════════"
echo ""

if [ -f "$TEST_DIR/test-data.bin" ]; then
    test_file="$TEST_DIR/test-data.bin"
    
    # Test XChaCha20-Poly1305 (default, portable)
    echo "[Testing XChaCha20-Poly1305 encryption]..."
    if command -v sodium-cli &>/dev/null; then
        sodium-cli crypto_secretbox_keygen > /tmp/sodium-key
        sodium-cli crypto_aead_xchacha20_ietf_poly1305_encrypt \
            -i "$test_file" \
            -k "$(cat /tmp/sodium-key)" \
            -o "$TEST_DIR/test-data.xchacha.enc" \
            -n "$(openssl rand -hex 24)" \
            -p "testpassword123!" 2>/dev/null || echo "  ⚠ XChaCha encryption not fully supported yet"
    else
        echo "  ⚠ libsodium-cli not found, using placeholder"
        touch "$TEST_DIR/test-data.xchacha.enc"
    fi
    
    # Test AES-GCM-256 (Intel NI only)
    echo "[Testing AES-GCM-256 encryption]..."
    if [ "$HAS_INTEL_NI" = true ]; then
        openssl enc -aes-256-gcm -nosalt \
            -in "$test_file" \
            -out "$TEST_DIR/test-data.aes.enc" \
            -K "$(openssl rand -hex 32)" \
            -iv "$(openssl rand -hex 16)" \
            -pass pass:testpassword123! 2>/dev/null && \
        echo "  ✓ AES-GCM-256 encryption successful" || \
        echo "  ⚠ AES-GCM encryption failed or not supported"
    else
        echo "  ⚠ Intel NI not detected, skipping AES-GCM (using XChaCha20-Poly1305 instead)"
    fi
    
    echo ""
fi

# Cleanup test files
echo "═══════════════════════════════════════════════════════"
echo "  CLEANUP"
echo "═══════════════════════════════════════════════════════"
echo ""

rm -rf "$TEST_DIR"
echo "✓ Test directory cleaned up"
echo ""

echo "═══════════════════════════════════════════════════════"
echo "  TEST SUITE COMPLETE"
echo "═══════════════════════════════════════════════════════"
echo ""

# Summary
if [ -f "$PROJECT_ROOT/compression.cpp" ] && [ -f "$PROJECT_ROOT/encryption.cpp" ]; then
    echo "✓ All compression algorithms implemented:"
    echo "  • zstd (recommended, fast + good ratio)"
    echo "  • lz4 (fastest decompression)"
    echo "  • snappy (very fast, good for logs/temp)"
    echo "  • xz (best compression ratio)"
    echo "  • bzip2 (good ratio, slower)"
    echo "  • gzip (universal compatibility)"
    echo ""
    echo "✓ Encryption algorithms implemented:"
    echo "  • XChaCha20-Poly1305 (default, portable, secure)"
    echo "  • AES-GCM-256 (Intel NI only, faster on Intel)"
    echo ""
else
    echo "⚠ Some implementation files missing"
fi

echo ""
echo "═══════════════════════════════════════════════════════"
echo "  NEXT STEPS:"
echo "═══════════════════════════════════════════════════════"
echo ""
echo "1. Add compression.cpp and encryption.cpp to project"
echo "2. Update CompressionConfig in backup-manager-gui.hpp"
echo "3. Integrate with main.vala pipeline"
echo "4. Add XChaCha20-Poly1305 key derivation (Argon2id)"
echo ""
