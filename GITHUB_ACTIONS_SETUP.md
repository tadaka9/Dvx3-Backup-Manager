# GitHub Actions Setup Guide

## Overview

This repository now has a complete GitHub Actions workflow that builds the Dvx3 Backup Manager for three platforms:
- **Linux** (Ubuntu x86_64)
- **macOS** (Universal binary - Intel + Apple Silicon)
- **Windows** (x64 with MSYS2)

## What Was Fixed

### macOS Issues (Previously Documented in TODO.md)
✅ **Qt6 Installation**: Changed from generic `qt` to explicit `qt@6` package
✅ **Path Configuration**: Proper PATH setup using `$(brew --prefix qt@6)/bin`
⚠️ **Note:** On some Homebrew installs, `qt` may be installed instead of `qt@6`.
If you encounter `No such keg: /opt/homebrew/Cellar/qt@6` or similar warnings, the workflow
will try to detect `qt@6`, `qt`, or `qt6` automatically, but for local builds you can export
`QT6_PREFIX=$(brew --prefix qt)` to make it explicit to the build scripts.
✅ **MOC Detection**: Checks for `moc` in both `libexec` and `bin` directories
✅ **Environment Variables**: Sets `QT_MOC_NATIVE` and `PKG_CONFIG_PATH` correctly
✅ **DMG Creation**: Creates proper `.app` bundle with `Info.plist` and uses `hdiutil` for DMG
✅ **macdeployqt**: Automatically bundles Qt frameworks into the app
✅ **Error Handling**: Comprehensive checks and clear error messages

### Windows Issues (Newly Implemented)
✅ **MSYS2 Setup**: Uses official `msys2/setup-msys2@v2` GitHub Action
✅ **MINGW64 Toolchain**: Proper mingw-w64 compiler and tools
✅ **All Dependencies**: Installs vala, glib2, json-glib, libsodium, qt6
✅ **DLL Packaging**: Automatically copies all required runtime DLLs:
  - GLib family (libglib-2.0-0.dll, libgobject-2.0-0.dll, etc.)
  - JSON-GLib (libjson-glib-1.0-0.dll)
  - Libsodium
  - Qt6 (Qt6Core.dll, Qt6Gui.dll, Qt6Widgets.dll)
  - MinGW runtime libraries
✅ **Qt6 Plugins**: Includes platform plugins (qwindows.dll) and styles
✅ **ZIP Distribution**: Creates ready-to-run package with README

## Workflow File Location

```
.github/workflows/build.yml
```

## Workflow Triggers

The workflow runs automatically on:
- **Push to main/master/develop branches**
- **Pull requests to main/master**
- **Version tags** (e.g., `v0.0.3a101125`)
- **Manual dispatch** (via GitHub Actions UI)

## Build Jobs

### 1. Linux Build (`build-linux`)
- Runs on: `ubuntu-latest`
- Builds: CLI (`dvx3`) and GUI (`backup-manager-gui`)
- Artifacts: Executables and shared library

### 2. macOS Build (`build-macos`)
- Runs on: `macos-latest`
- Builds: Universal binary (Intel + Apple Silicon)
- Creates: `.app` bundle and `.dmg` installer
- Artifacts: DMG file and app bundle

### 3. Windows Build (`build-windows`)
- Runs on: `windows-latest` with MSYS2
- Builds: CLI (`Dvx3.exe`) and GUI (`backup-manager-gui.exe`)
- Creates: ZIP package with all DLLs
- Artifacts: ZIP file and extracted folder

### 4. Release Creation (`create-release`)
- Runs on: `ubuntu-latest`
- Triggers: Only on version tags (e.g., `v1.0.0`)
- Creates: GitHub Release with all platform artifacts

## How to Use

### Testing the Workflow

1. **Push to GitHub**:
   ```bash
   git add .github/workflows/build.yml TODO.md
   git commit -m "Add GitHub Actions workflow for multi-platform builds"
   git push origin main
   ```

2. **Check Workflow Status**:
   - Go to your repository on GitHub
   - Click on "Actions" tab
   - You should see the workflow running

3. **Download Artifacts**:
   - Click on a completed workflow run
   - Scroll down to "Artifacts" section
   - Download platform-specific builds

### Creating a Release

1. **Create and push a version tag**:
   ```bash
   git tag v0.0.3a101125
   git push origin v0.0.3a101125
   ```

2. **Automatic Release**:
   - The workflow will automatically create a GitHub Release
   - All platform artifacts will be attached
   - Release notes will be auto-generated

### Manual Workflow Trigger

1. Go to "Actions" tab on GitHub
2. Select "Multi-Platform Build" workflow
3. Click "Run workflow" button
4. Select branch and click "Run workflow"

## Build Outputs

### Linux
- `backup-manager-gui` - Qt6 GUI application
- `dvx3` - CLI tool
- `libdvx3.so` - Shared library
- `dvx3.h`, `dvx3.vapi` - Development headers

### macOS
- `Dvx3-BackupManager-macOS-{VERSION}.dmg` - Installer
- `Dvx3 Backup Manager.app` - Application bundle

### Windows
- `Dvx3-BackupManager-Windows-x64-{VERSION}.zip` - Complete package
- Contains:
  - `backup-manager-gui.exe` - GUI application
  - `Dvx3.exe` - CLI tool
  - All required DLLs
  - Qt6 plugins
  - README.txt

## Troubleshooting

### macOS Build Fails
- Check if Qt6 is properly installed: Look for "Verify Qt6 installation" step
- Verify moc was found: Check "Setup Qt6 environment" step
- Check build outputs: Look for "Verify build outputs" step

### Windows Build Fails
- Check MSYS2 setup: Look for "Setup MSYS2" step
- Verify dependencies: Check package installation logs
- Check DLL copying: Look for "Package Windows build" step

### Linux Build Fails
- Check dependency installation: Look for "Install dependencies" step
- Verify build scripts: Check if `build.sh` and `build_gui.sh` are executable

## Environment Variables

The workflow uses these environment variables:
- `VERSION`: Set to `0.0.3a101125` (update as needed)
- `QT6_DIR`: macOS Qt6 installation directory
- `QT_MOC_NATIVE`: Path to Qt's moc tool
- `PKG_CONFIG_PATH`: For finding Qt6 packages

## Next Steps

1. ✅ Workflow created and documented
2. ⏳ Push to GitHub to trigger first build
3. ⏳ Test all three platforms
4. ⏳ Verify artifacts work correctly
5. ⏳ Create a version tag to test release creation
6. ⏳ Download and test packaged applications

## Support

If you encounter issues:
1. Check the workflow logs in GitHub Actions
2. Review the specific step that failed
3. Check the TODO.md for known issues
4. Verify all build scripts are present and executable

## Files Modified/Created

- ✅ `.github/workflows/build.yml` - Main workflow file (NEW)
- ✅ `TODO.md` - Updated with Windows fixes and workflow status
- ✅ `GITHUB_ACTIONS_SETUP.md` - This documentation (NEW)

## Comparison with GitLab CI

The GitHub Actions workflow is equivalent to the GitLab CI configuration but:
- Uses GitHub-specific actions (checkout@v4, upload-artifact@v4, etc.)
- Uses MSYS2 action for Windows instead of shell runner
- Uses native macOS runner instead of shell runner
- Automatically creates releases on tags
- Provides better artifact management
