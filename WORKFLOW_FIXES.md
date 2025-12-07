# GitHub Actions Workflow Fixes

## Summary of Changes

This document describes the fixes applied to `.github/workflows/c-cpp.yml` to make the CI/CD pipeline work correctly.

## Issues Fixed

### 1. **Linux Build Matrix Configuration**
**Problem:** The matrix was incorrectly configured with duplicate combinations, and the `arch` variable wasn't properly used.

**Fix:**
- Removed `arch` from the matrix configuration
- Simplified to only use `os: [ubuntu-latest, ubuntu-22.04]`
- Updated job name to reflect x86_64 architecture explicitly
- Updated artifact name to include the matrix OS variable

### 2. **Missing build.sh Call**
**Problem:** Several jobs were calling `build_gui.sh` without first building the library with `build.sh`.

**Fix:**
- Added `bash ./build.sh` before `bash ./build_gui.sh` in:
  - Linux build job
  - ARM32 Debian 13 job
  - ARM64 Debian 13 job

### 3. **macOS Universal Binary Creation**
**Problem:** The universal binary creation was trying to copy the app bundle after creating the universal binaries, which would overwrite them.

**Fix:**
- Copy the app bundle structure FIRST from arm64 (newer runner)
- Then create universal binaries by combining x86_64 and arm64 binaries using `lipo`
- Add verification step with `lipo -info` to confirm universal binaries
- Remove the redundant `macdeployqt` call (already done in individual builds)
- Add Qt@6 and create-dmg installation step

### 4. **Windows Build Simplification**
**Problem:** Windows build had inline Qt MOC/RCC compilation that duplicated logic from `build_gui.sh`.

**Fix:**
- Replaced inline Qt compilation with `bash ./build_gui.sh`
- Added packaging step to collect all Windows artifacts including dependencies
- Use `ldd` to automatically copy required MSYS2 DLLs
- Changed artifact upload to use the packaged directory

### 5. **Checksum Generation**
**Problem:** Syntax error in find command with escaped dollar signs causing the command to fail.

**Fix:**
- Changed from complex `xargs` pipeline to simpler `find -exec` command
- Fixed syntax: `find . -type f \( -name "*.AppImage" ... \) -exec sha256sum {} \; > CHECKSUMS.txt`
- Simplified file pattern matching

### 6. **Job Dependencies**
**Problem:** Release job referenced `build-linux-x86_64` which was renamed.

**Fix:**
- Updated `needs` in `create-release` job to reference `build-linux`

## Testing Recommendations

Before pushing, verify:

1. **Syntax validation:**
   ```bash
   yamllint .github/workflows/c-cpp.yml
   ```

2. **Build scripts are executable:**
   ```bash
   chmod +x build.sh build_gui.sh build-appimage.sh build-raspberry.sh
   ```

3. **Required files exist:**
   - `vala-extra-vapis/libsodium.vapi`
   - `resources.qrc`
   - `dvx3-backup.png`
   - All `.vala` source files
   - All `.cpp` and `.hpp` files

4. **Local build test (Linux/macOS):**
   ```bash
   ./build.sh
   ./build_gui.sh
   ```

## Expected Workflow Behavior

### On Push to Branches
- Builds for all platforms (Linux, macOS, Windows, ARM)
- Creates artifacts for each platform
- Artifacts retained for 90 days

### On Tag Push (v*)
- All builds execute
- Release is automatically created
- All artifacts attached to release
- Checksums generated for all binaries
- Release notes auto-generated

## Build Artifacts

| Platform | Artifact Name | Contents |
|----------|--------------|----------|
| Linux (ubuntu-latest) | Dvx3-BackupManager-Linux-ubuntu-latest-x86_64-AppImage | AppImage file |
| Linux (ubuntu-22.04) | Dvx3-BackupManager-Linux-ubuntu-22.04-x86_64-AppImage | AppImage file |
| macOS Universal | Dvx3-BackupManager-macOS-Universal | DMG file |
| Windows x64 | Dvx3-BackupManager-Windows-x64 | EXE, DLL, and dependency files |
| Raspberry Pi ARMv7 | Dvx3-BackupManager-RaspberryPi-ARMv7 | tar.gz package |
| Raspberry Pi ARM64 | Dvx3-BackupManager-RaspberryPi-ARM64 | tar.gz package |

## Additional Notes

- macOS builds create individual App Bundles for x86_64 and arm64, then combine them into a Universal app
- Windows build automatically collects MSYS2 dependencies
- ARM builds run in Docker containers with QEMU emulation
- All builds verify the presence of `libsodium.vapi` before proceeding
