# Repository audit and refactor

Inspection covered tracked Vala/C/C++ sources, Qt resources/CMake, build/test/lint/
installation scripts, hooks, workflow and documentation. The specified local checkout
matches upstream commit 5bdc85d32a9f962740d4efc452f3af1ee88c8e66 and had no tracked
local modifications before this work. The legacy nested clone-local gitlink points to an older clean copy with no unpushed
branch commits. It is archived outside the repository before removal; old generated
root VAPI, duplicate bindings and empty cli trees are removed.

## Contradictions found

- build.sh contained invalid double braces, missing argument parsing/manager/test targets,
  unset toolchain variables, nonexistent --capi/package helpers and swallowed failures.
- Make/tests/documentation named targets and paths not produced by the build.
- The vala/ tree was pseudocode with undefined types/functions and mock cryptography,
  conflicting with the root Vala API and archive format.
- The root engine fed tar bytes straight into encryption while launching an unused zstd
  process, reread an unwritten header for integrity and accumulated plaintext unboundedly.
- The checked-in generated header contained absolute developer paths and a stale API.
- The C++ manager duplicated persistence, directory walking and platform handling;
  its whitespace-based history format broke names/paths and saved passwords.
- Qt did not link the core and claimed success with mocked operations and invalid CLI
  commands. Documentation claimed AES-GCM, schedulers and settings absent from the code.
- CI claimed unsupported foreign CPUs/toolchains and invoked missing package scripts.
- Legacy Qt/libsodium helpers and lint wrappers hid failures; Makefile/source VAPI were
  ignored while stale generated bindings were treated as canonical.

## Changes

Canonical engine and manager service are Vala; C/C++ is limited to native bindings,
RAII wrappers, Qt presentation and binding examples/tests. One native build driver
and output tree serve Make/tests/CI. Removed duplicate root Vala/core header, C++
manager, unreliable manual tests and obsolete Qt/PIC helpers. Updated guides and
removed unsupported platform/package/release claims.

Removed unused QRC/theme, duplicate logo and redundant pre-commit configuration/wrapper.
The primary logo remains as README branding. One .githooks configuration and one lint
entrypoint remain. No application configuration or backup archive is deleted.

## Evidence

Local Linux builds core/CLI/manager/GUI; Vala functional tests, C++ byte round trip,
CLI and offscreen GUI smoke tests pass. Verified codecs: none, zstd, gzip, bzip2,
xz, lzma, lz4, brotli, 7z, zpaq and an xz -> zstd pipeline.
Candidate runner jobs are configured, not claimed as observed successful runs.
See BUILD.md and COMPRESSION.md for exact dependencies/status and remaining limitations.
