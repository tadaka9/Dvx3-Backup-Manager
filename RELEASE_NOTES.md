# Unreleased changes

- Consolidated the real Vala engine under vala/core; removed incompatible pseudocode
  and the duplicate root implementation/generated header.
- Replaced the C++ manager backend/CLI with Vala services and commands.
- Rebuilt build.sh, Makefile and test entrypoint around one native output layout.
- Removed unsupported cross-compilation and nonexistent packaging jobs.
- Added native Linux, macOS and MSYS2 candidate CI jobs with actual archive tests.
- Corrected tar/compression/encryption ordering, bounded chunk reads and incremental
  SHA-256; check every subprocess exit status and authenticate before extraction.
- Added version-2 codec metadata/header authentication, private staging, atomic output
  replacement and compatibility with valid legacy zstd framing.
- Added selectable codecs including tested ZPAQ and reversible local codec pipelines.
- Replaced the simulated Qt GUI with real worker-thread calls to the Vala C API.

Breaking manager change: jobs/history now use GLib KeyFile and do not persist passwords.
Legacy manager configuration/history need manual recreation; old files are preserved.
New codec archives are not guaranteed readable by old binaries.

This is not a released package or proof of every candidate platform. See BUILD.md
for actual verification and ARCHITECTURE.md for disk-staging/security tradeoffs.
Prior release claims without repository evidence were removed rather than republished.
