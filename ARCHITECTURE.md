# Architecture

The canonical engine is `vala/core/dvx3.vala`. Job persistence, execution,
history and retention live in `vala/manager/manager.vala`, built into the same
library. Every frontend uses that engine; no independent C++ backend remains.

```text
Vala CLI                     Vala manager CLI             Qt6 C++ presentation
vala/cli/app.vala             vala/manager/app.vala         gui/qt/qtdesktop/main.cpp
      \                              |                      / dvx3.hpp (RAII only)
       \                             |                     / generated C API
        +-------------------- libdvx3 --------------------+
                vala/core/dvx3.vala + vala/manager/manager.vala
                              |
          GIO paths/streams/processes + libsodium + external codecs/tar
```

Vala compiles to C with `valac -C --header --vapi --library`. Native C tools
compile that generated output; generated C, headers and VAPI are never source
of truth. `vala/bindings/libsodium.vapi` is a small **source binding**, including
64-bit lengths appropriate for Windows as well as POSIX.
`dvx3.hpp` owns C references and translates `GError` to exceptions.
C++ remains for the Qt interface, a wrapper and ABI tests/examples only.

## Portable operations and OS boundaries

GLib chooses native configuration/temp directories. GIO owns file I/O and
subprocess lifetimes; tools are found on PATH. `DVX3_TAR` can select a compatible
tar executable, otherwise gtar is preferred when available and tar is the fallback.
Subprocesses use argv arrays, working directories and portable GIO pipes with
concurrent, bounded-memory streaming between files and stdin/stdout,
with no `sh -c`, shell pipelines, POSIX file descriptors or waitpid calls.
Every child exit status is checked. The build handles native OS/CPU detection,
Windows `.exe`/DLL naming, macOS dylibs and Linux shared objects.

Archive/compression backends are replaceable external tools because these
algorithms are maintained in mature native implementations. Vala controls
selection, validation, reversible pipelines, encryption and error handling.
The extension mechanism accepts local codec profiles; it does not execute
commands supplied by an archive. See [COMPRESSION.md](COMPRESSION.md).

## Archive pipeline and compatibility

Creation stages tar and compressed payload in a private GLib temporary directory,
then encrypts bounded 1 MiB chunks with Argon2id (2 iterations, 64000 KiB) and
libsodium XSalsa20-Poly1305 secretbox, using a fresh random salt and nonce per
chunk. SHA-256 is computed incrementally over the compressed payload.
The new version-2 JSON header records codec, chunk framing and KDF parameters
and carries a libsodium authentication tag. The existing 4-byte big-endian
length + 512-byte zero-padded JSON + nonce/ciphertext framing is retained.

Output is written privately to a random `.partial` file beside the destination,
then replaced after success. Failure preserves an existing output. Derived
keys are wiped. Temporary files and staged output are removed on normal success
or reported failure; cleanup failures are reported, not ignored.
Abrupt termination/power loss can leave staging files.

Restore bounds and validates metadata, authenticates all encrypted chunks and
checks available SHA-256 before decompression/extraction. The destination must
be empty. No restore has permission to overwrite existing files. Extraction
errors are reported but may leave a partially populated restore directory.
Archive extraction relies on the installed tar implementation's safety rules;
this is not a sandbox for malicious archives created by someone who knows the password.

Legacy headers without version/codec default to zstd and may omit SHA-256/header
authentication. Legacy compatibility necessarily has weaker metadata guarantees;
there is no authenticated distinction between an old header and a downgraded new
one. Malformed archives produced by the previous broken pipeline are not repaired
by the build refactor. Old readers are not guaranteed to understand new codecs.

**Tradeoff:** private plaintext tar/compressed staging consumes disk and adds I/O;
this implementation does not claim a zero-plaintext, fully streaming pipeline.
Pipelines need additional temporary space. Permissions protect those files on
POSIX; confidentiality against disk forensics requires an encrypted temp volume.

## Frontends and manager

The CLI retains `encrypt` / `decrypt` and adds codec selection/status/version.
The manager persists jobs/history with GLib KeyFile, uses GLib's user configuration
directory and never stores passwords. Backup destinations inside a source are
excluded recursively. Retention only deletes UUID-named archives recorded by the
manager in their configured directory, and errors are surfaced.
The new manager format is `jobs.ini` / `history.ini`; the legacy C++ configuration
and history are not imported automatically. See the migration instructions in
[BACKUP_MANAGER_GUIDE.md](BACKUP_MANAGER_GUIDE.md).

Qt calls the generated C API through `dvx3.hpp` in a worker thread and delivers
progress/completion to the UI via signals. There are no fake successes, mock
progress bars, password-bearing shell commands, or pretend scheduler/settings.
The window cannot close while an operation is active. Cancellation is not yet
implemented. The GUI handles create/restore; job administration stays in the
Vala manager CLI.

## Build and testing

One driver supplies `core/cli/manager/gui/all/clean/test`, delegated by Make and
the test script. Vala functional tests verify bytes, hidden files, Unicode/quoted
paths, multi-chunk framing, incorrect passwords, damage/truncation/header tampering,
legacy framing and job exclusion/persistence/retention. C++ tests verify the ABI.
CI requires native builds and round trips rather than foreign compiler smoke tests.
See [BUILD.md](BUILD.md) for actual platform verification status and requirements.
