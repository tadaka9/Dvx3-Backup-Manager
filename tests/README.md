# Cryptographic Test Suite

This directory contains the cryptographic test suite for Dvx3 Backup Manager.

## Tests Overview

The test suite validates the security and correctness of the encryption implementation using Argon2id + XSalsa20-Poly1305:

| Test | Description | Status |
|------|-------------|--------|
| **test_basic_roundtrip** | Basic encryption/decryption roundtrip | ✅ Pass |
| **test_integrity_verification** | SHA-256 integrity verification | ✅ Pass |
| **test_wrong_password_detection** | Wrong password rejection | ✅ Pass |
| **test_large_file_encryption** | Large file (1 MiB) performance | ✅ Pass |
| **test_unicode_content** | Unicode content handling | ✅ Pass |
| **test_empty_data** | Empty data edge case | ✅ Pass |

## Running Tests

### Quick Start

```bash
./tests/run-crypto-tests.sh
```

### Manual Compilation and Execution

```bash
# Compile
valac -g -c tests/cryptographic-tests.vala \
    -I/usr/include/glib-2.0 \
    -I/usr/lib/x86_64-linux-gnu/glib-2.0/include \
    -I/usr/include/json-glib-1.0 \
    -I/usr/lib/x86_64-linux-gnu/json-glib-1.0/include \
    -lsodium \
    -o tests/cryptographic-tests

# Run
./tests/cryptographic-tests
```

## Requirements

- **valac** (Vala compiler) ≥ 0.56
- **libsodium-dev** (≥ 1.0.18)
- **GLib** development files
- **json-glib** development files

Install dependencies:

```bash
sudo apt install valac libsodium-dev libglib2.0-dev libjson-glib-dev
```

## Test Details

### test_basic_roundtrip
Verifies that data can be encrypted and decrypted correctly, preserving the original content exactly.

### test_integrity_verification
Computes SHA-256 hash of the original data and verifies it matches after encryption/decryption cycle. Ensures no data corruption occurs.

### test_wrong_password_detection
Attempts to decrypt data with an incorrect password to ensure authentication fails properly (cryptographic security).

### test_large_file_encryption
Tests performance with 1 MiB of data, measuring encryption/decryption time and verifying correctness.

### test_unicode_content
Validates that Unicode characters (emoji, CJK, Arabic, Hebrew, Korean) are preserved correctly through the encryption cycle.

### test_empty_data
Ensures edge case of zero-byte data is handled correctly without crashes or errors.

## Security Properties Verified

- ✅ **Confidentiality**: Data remains encrypted with correct key
- ✅ **Integrity**: SHA-256 verification ensures no tampering
- ✅ **Authentication**: MAC (Poly1305) prevents unauthorized decryption
- ✅ **Key Derivation**: Argon2id provides secure password-to-key conversion
- ✅ **Plaintext Awareness**: Wrong passwords are cryptographically rejected

## CI Integration

Add to your CI pipeline:

```yaml
- name: Run Cryptographic Tests
  run: ./tests/run-crypto-tests.sh
  if: success() || failure()  # Run on all builds
```

## License

MIT License - See [LICENSE](<../LICENSE>) in the project root.
