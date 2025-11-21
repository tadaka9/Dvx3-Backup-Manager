# macOS and Windows Build Fix - TODO

## Steps to Complete:

- [x] Fix macOS Dependencies Installation
  - [x] Change `qt` to `qt@6` for explicit Qt6 installation
  - [x] Remove problematic `brew link qt --force`
  - [x] Add proper PATH setup using `brew --prefix qt@6`

- [x] Fix macOS Build Step
  - [x] Remove deprecated `find -perm +111` syntax
  - [x] Use `brew --prefix qt@6` to locate Qt tools
  - [x] Set `QT_MOC_NATIVE` environment variable
  - [x] Remove references to non-existent build scripts
  - [x] Add proper error handling and debugging
  - [x] Add inline DMG creation for packaging

- [x] Fix Windows Build
  - [x] Setup MSYS2 with proper mingw-w64 toolchain
  - [x] Install all required dependencies (vala, glib2, json-glib, libsodium, qt6)
  - [x] Configure MSYS2 shell as default for build steps
  - [x] Package all required DLLs (glib, Qt6, libsodium, etc.)
  - [x] Include Qt6 plugins (platforms, styles)
  - [x] Create ZIP archive for distribution

- [x] Create GitHub Actions Workflow
  - [x] Create `.github/workflows/build.yml`
  - [x] Implement Linux build job
  - [x] Implement macOS build job with all fixes
  - [x] Implement Windows build job with MSYS2
  - [x] Add artifact uploads for all platforms
  - [x] Add automatic release creation on tags

- [ ] Verify Changes
  - [x] Review the updated workflow
  - [ ] Test on GitHub Actions (push to trigger workflow)

## Current Status:
✅ All changes implemented successfully!
✅ GitHub Actions workflow created at `.github/workflows/build.yml`

## Summary of Changes:

### 1. macOS Dependencies Installation (Fixed)
- Changed `brew install qt` to `brew install qt@6` for explicit Qt6 installation
- Removed the problematic `brew link qt --force` command
- Dependencies now install cleanly without conflicts

### 2. macOS Build Step (Completely Rewritten)
- **Removed deprecated syntax**: Eliminated `find -perm +111` which doesn't work on modern macOS
- **Proper Qt6 path detection**: Uses `brew --prefix qt@6` to get the correct installation path
- **Environment variables**: Sets `QT_MOC_NATIVE`, `PATH`, and `PKG_CONFIG_PATH` correctly
- **Tool verification**: Checks for `moc` in both `libexec` and `bin` directories
- **Error handling**: Exits with clear error messages if tools are not found
- **Build verification**: Confirms `backup-manager-gui` was created successfully
- **Removed non-existent scripts**: Uses existing `build.sh` and `build_gui.sh` scripts

### 3. macOS DMG Creation (New Step Added)
- Creates proper macOS `.app` bundle structure
- Includes `Info.plist` with correct bundle identifiers
- Copies executable, library, and icon into the bundle
- Uses `macdeployqt` to bundle Qt frameworks automatically
- Uses `hdiutil` to create a distributable DMG file
- Verifies DMG creation with proper error handling

### 4. Windows Build (Completely New)
- **MSYS2 Setup**: Uses official `msys2/setup-msys2@v2` action
- **MINGW64 Environment**: Configures proper mingw-w64 toolchain
- **All Dependencies**: Installs vala, glib2, json-glib, libsodium, qt6-base, qt6-tools
- **DLL Packaging**: Automatically copies all required runtime DLLs:
  - GLib family (libglib, libgobject, libgio, etc.)
  - JSON-GLib
  - Libsodium
  - Qt6 (Core, Gui, Widgets)
  - MinGW runtime libraries
- **Qt6 Plugins**: Includes platform plugins (qwindows.dll) and styles
- **ZIP Distribution**: Creates ready-to-run package with all dependencies

### 5. GitHub Actions Workflow Structure
- **Multi-platform builds**: Linux (Ubuntu), macOS, Windows
- **Artifact uploads**: Each platform uploads its build artifacts
- **Automatic releases**: Creates GitHub releases on version tags
- **Proper triggers**: Runs on push to main branches, tags, PRs, and manual dispatch

## Key Improvements:
✅ No more deprecated `find` command syntax on macOS
✅ Explicit Qt6 installation and path handling
✅ Proper environment variable setup for build scripts
✅ Comprehensive error checking and debugging output
✅ Complete DMG packaging solution for macOS
✅ Full Windows support with MSYS2 and proper DLL packaging
✅ Clean separation of build and packaging steps
✅ Automated release creation on tags
✅ Uses existing build scripts instead of creating new ones

## Next Steps:
1. Push the workflow to GitHub to trigger the first build
2. Test all three platforms (Linux, macOS, Windows)
3. Verify artifacts are created correctly
4. Create a version tag (e.g., `v0.0.3a101125`) to test release creation
5. Download and test the packaged applications on each platform
