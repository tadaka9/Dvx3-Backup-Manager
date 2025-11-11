# dvx3 - Encrypted Archive Library

A high-performance encrypted archive library for Vala/C using:
- **tar** for archiving
- **zstd** for compression (level 22, 16 threads)
- **Argon2id** for key derivation
- **XSalsa20-Poly1305** (Secretbox) for authenticated encryption

## Features

- ✅ **Zero intermediate files** - streaming pipeline from start to finish
- ✅ **Memory efficient** - 1 MiB chunk processing
- ✅ **Progress callbacks** - track encryption/decryption progress
    - Encryption: reports compressed-bytes processed and a dynamically predicted final compressed size when GNU tar is available; falls back to a static estimate otherwise
- ✅ **Strong security** - Argon2id KDF + authenticated encryption
- ✅ **C/Vala API** - use as library or CLI tool

## Build

```bash
./build.sh
```

This creates:
- `libdvx3.so` - Shared library
- `dvx3.vapi` - Vala API bindings
- `dvx3.h` - C header file
- `dvx3` - CLI executable

## CLI Usage

### Encrypt
```bash
./dvx3 encrypt /path/to/folder -p "password" -o backup.dvx3
```

Options:
- `-p, --password` - Encryption password (required)
- `-o, --output` - Output file (auto-adds `.dvx3` extension)
- `-i, --in-place` - Allow output inside source folder (will be excluded)

### Decrypt
```bash
./dvx3 decrypt backup.dvx3 -p "password" -o /restore/to
```

Options:
- `-p, --password` - Decryption password (required)
- `-o, --output` - Output directory (default: strips `.dvx3` from filename)

## Library API (Vala)

```vala
using Dvx3;

// Encrypt a directory
void encrypt_example () {
    var src = File.new_for_path("/my/folder");
    var dst = File.new_for_path("backup.dvx3");
    
    try {
        Dvx3.encrypt(
            src,
            dst,
            "my-password",
            null,  // exclude_path (optional)
            (processed, total, output) => {
                // Progress callback
                stdout.printf("%.1f%%\n", (double)processed / total * 100);
            }
        );
    } catch (Error e) {
        stderr.printf("Error: %s\n", e.message);
    }
}

// Decrypt an archive
void decrypt_example () {
    var enc = File.new_for_path("backup.dvx3");
    var dst = File.new_for_path("/restore/to");
    
    try {
        Dvx3.decrypt(
            enc,
            dst,
            "my-password",
            (processed, total, output) => {
                // Progress callback
                stdout.printf("%.1f%%\n", (double)processed / total * 100);
            }
        );
    } catch (Error e) {
        stderr.printf("Error: %s\n", e.message);
    }
}
```

## Library API (C)

```c
#include <dvx3.h>
#include <gio/gio.h>

void encrypt_example(void) {
    GFile *src = g_file_new_for_path("/my/folder");
    GFile *dst = g_file_new_for_path("backup.dvx3");
    GError *error = NULL;
    
    dvx3_encrypt(src, dst, "my-password", NULL, NULL, &error);
    
    if (error) {
        g_printerr("Error: %s\n", error->message);
        g_error_free(error);
    }
    
    g_object_unref(src);
    g_object_unref(dst);
}

void decrypt_example(void) {
    GFile *enc = g_file_new_for_path("backup.dvx3");
    GFile *dst = g_file_new_for_path("/restore/to");
    GError *error = NULL;
    
    dvx3_decrypt(enc, dst, "my-password", NULL, &error);
    
    if (error) {
        g_printerr("Error: %s\n", error->message);
        g_error_free(error);
    }
    
    g_object_unref(enc);
    g_object_unref(dst);
}
```

## Archive Format

```
┌─────────────────────────────────────────┐
│ 4 bytes: JSON header length (BE)        │
├─────────────────────────────────────────┤
│ JSON header:                            │
│   - salt (base64)                       │
│   - chunks count                        │
│   - last_chunk_size                     │
│   - argon2 parameters                   │
├─────────────────────────────────────────┤
│ Encrypted chunks (repeat N times):      │
│   ┌─────────────────────────────────┐   │
│   │ 24 bytes: nonce                 │   │
│   ├─────────────────────────────────┤   │
│   │ ciphertext (1 MiB + 16 byte MAC)│   │
│   └─────────────────────────────────┘   │
└─────────────────────────────────────────┘
```

## Security Parameters

- **Argon2id**:
  - Time cost: 2 iterations
  - Memory: 64 MB
  - Parallelism: 4 threads
  
- **XSalsa20-Poly1305**:
  - 256-bit key (derived from password)
  - 192-bit nonce (random per chunk)
  - 128-bit MAC

## Dependencies

- Vala 0.56+
- GLib 2.0
- GIO Unix 2.0
- JSON-GLib 1.0
- libsodium
- tar (command-line tool) — GNU tar recommended for dynamic progress
- zstd (command-line tool)

## Dynamic Progress Estimation

When encrypting, the library streams `tar | zstd` and encrypts on the fly. To provide meaningful progress:
- On systems with GNU tar, we send `SIGUSR1` to tar and parse its running totals (original bytes processed). From the observed compressed/original ratio so far, we predict the final compressed size and update the progress bar accordingly.
- On systems without GNU tar (e.g., BSD tar on macOS), the library falls back to a static estimate (initially ~50% of original size). The GUI labels such progress as approximate.

Notes:
- Actual final compressed size may vary depending on content and zstd level.
- The progress callback signature is `(processed, total, output)` where:
    - `processed` = compressed bytes produced so far
    - `total` = predicted final compressed size (dynamic if GNU tar is present, heuristic otherwise)
    - `output` = encrypted bytes written to the archive so far

## File Structure

- `libdvx3.vala` - Core library implementation
- `dvx3-cli.vala` - Command-line interface
- `build.sh` - Build script
- `vala-extra-vapis/libsodium.vapi` - libsodium bindings

## License

See project license file.
