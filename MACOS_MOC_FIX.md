# macOS MOC Detection Fix

## Problem
The macOS build in GitHub Actions was failing at step [4/5] with the error:
```
Error: moc not found. Install Qt6 development tools.
```

## Root Cause
The `build_gui.sh` script was checking for Qt MOC (Meta-Object Compiler) in Linux and Windows (MSYS2) paths, but not in macOS Homebrew-specific locations where Qt6 tools are installed.

### Paths Checked (Before Fix):
- `$QT_MOC_NATIVE` environment variable
- `/mingw64/bin/moc` (Windows/MSYS2)
- `/usr/lib/qt6/moc` (Linux)
- `/usr/lib/qt6/libexec/moc` (Linux)
- `moc-qt6`, `moc6`, `moc` (commands in PATH)

### Missing Paths (macOS Homebrew):
- `/opt/homebrew/opt/qt/bin/moc` (Apple Silicon)
- `/opt/homebrew/opt/qt@6/bin/moc` (Apple Silicon, versioned)
- `/usr/local/opt/qt/bin/moc` (Intel Mac)
- `/usr/local/opt/qt@6/bin/moc` (Intel Mac, versioned)
- `/opt/homebrew/bin/moc` (Homebrew bin directory)
- `/usr/local/bin/moc` (Intel Homebrew bin)

## Solution

### 1. Updated `build_gui.sh`
Added macOS Homebrew-specific moc detection paths after the `QT_MOC_NATIVE` check but before MSYS2 paths:

```bash
# Check macOS Homebrew paths (Apple Silicon and Intel)
elif [ -x /opt/homebrew/opt/qt/bin/moc ]; then
    MOC=/opt/homebrew/opt/qt/bin/moc
    RCC=/opt/homebrew/opt/qt/bin/rcc
elif [ -x /opt/homebrew/opt/qt@6/bin/moc ]; then
    MOC=/opt/homebrew/opt/qt@6/bin/moc
    RCC=/opt/homebrew/opt/qt@6/bin/rcc
elif [ -x /usr/local/opt/qt/bin/moc ]; then
    MOC=/usr/local/opt/qt/bin/moc
    RCC=/usr/local/opt/qt/bin/rcc
elif [ -x /usr/local/opt/qt@6/bin/moc ]; then
    MOC=/usr/local/opt/qt@6/bin/moc
    RCC=/usr/local/opt/qt@6/bin/rcc
elif [ -x /opt/homebrew/bin/moc ]; then
    MOC=/opt/homebrew/bin/moc
    RCC=/opt/homebrew/bin/rcc
elif [ -x /usr/local/bin/moc ]; then
    MOC=/usr/local/bin/moc
    RCC=/usr/local/bin/rcc
```

Also improved error messages to show all searched locations including macOS paths for better debugging.

### 2. Enhanced `.github/workflows/build.yml`
Improved the macOS build job to:
- Try installing both `qt` and `qt@6` packages (Homebrew naming varies)
- Dynamically detect which Qt package is installed
- Search for moc in both `bin` and `libexec` directories
- Set `QT_MOC_NATIVE` environment variable appropriately
- Provide comprehensive Qt6 installation diagnostics

Key changes:
```yaml
- name: Install dependencies
  run: |
    brew update || true
    # Install Qt6 - try both 'qt' and 'qt@6' packages
    brew install vala glib json-glib libsodium qt cmake pkg-config || \
    brew install vala glib json-glib libsodium qt@6 cmake pkg-config || \
    brew upgrade vala glib json-glib libsodium qt cmake pkg-config || true

- name: Setup Qt6 environment
  run: |
    # Detect Qt installation (try both 'qt' and 'qt@6')
    if brew --prefix qt >/dev/null 2>&1; then
      QT_PREFIX="$(brew --prefix qt)"
      echo "Using Qt at: $QT_PREFIX"
    elif brew --prefix qt@6 >/dev/null 2>&1; then
      QT_PREFIX="$(brew --prefix qt@6)"
      echo "Using Qt@6 at: $QT_PREFIX"
    else
      echo "ERROR: Qt not found in Homebrew!"
      exit 1
    fi
    
    # Set up environment
    echo "$QT_PREFIX/bin" >> $GITHUB_PATH
    echo "QT6_DIR=$QT_PREFIX" >> $GITHUB_ENV
    echo "PKG_CONFIG_PATH=$QT_PREFIX/lib/pkgconfig:$PKG_CONFIG_PATH" >> $GITHUB_ENV
```

## Files Modified

1. **build_gui.sh**
   - Added macOS Homebrew-specific moc detection paths
   - Supports both Apple Silicon (`/opt/homebrew`) and Intel Mac (`/usr/local`) installations
   - Improved error messages with searched locations
   - Maintained backward compatibility with Linux/Windows

2. **.github/workflows/build.yml**
   - Enhanced "Install dependencies" step to try both `qt` and `qt@6` packages
   - Added dynamic Qt detection in "Setup Qt6 environment" step
   - Improved "Verify Qt6 installation" step with better diagnostics and fallback checks
   - Sets `QT_MOC_NATIVE` environment variable for build script

3. **MACOS_MOC_FIX.md** (this file)
   - Documents the fix implementation
   - Provides troubleshooting information

4. **TODO.md**
   - Updated to reflect the additional workflow verification improvements

## Testing
To test the fix:
1. Push changes to GitHub
2. Monitor the macOS build job in GitHub Actions
3. Check the "Verify Qt6 installation" step output
4. Verify that the "Build GUI" step completes successfully
5. Confirm macOS artifacts (DMG and .app) are created

## Expected Outcome
- macOS build should now find moc at the appropriate Homebrew location
- Build should complete successfully through all 5 steps
- macOS DMG and .app artifacts should be created with bundled Qt frameworks

## Compatibility
The fix maintains full compatibility with:
- ✅ macOS Apple Silicon (M1/M2/M3) - `/opt/homebrew` paths
- ✅ macOS Intel - `/usr/local` paths
- ✅ Linux (Ubuntu) - existing paths still checked
- ✅ Windows (MSYS2/MINGW64) - existing paths still checked

## Homebrew Qt Package Notes
Homebrew may install Qt as either:
- `qt` - Latest Qt6 version (e.g., Qt 6.9.3)
- `qt@6` - Versioned Qt6 package

The fix handles both naming conventions by:
1. Trying to install both packages (one will succeed)
2. Dynamically detecting which is installed
3. Using the detected prefix for all Qt operations

## Related Issues
This fix resolves the macOS build failure reported in the GitHub Actions workflow where the Qt MOC tool could not be found during the GUI build process, similar to the Windows fix documented in WINDOWS_MOC_FIX.md.

## Troubleshooting

### If moc is still not found:
1. Check which Qt package is installed:
   ```bash
   brew list | grep qt
   ```

2. Find the Qt installation prefix:
   ```bash
   brew --prefix qt
   # or
   brew --prefix qt@6
   ```

3. Verify moc location:
   ```bash
   ls -la $(brew --prefix qt)/bin/moc
   # or
   ls -la $(brew --prefix qt)/libexec/moc
   ```

4. Manually set `QT_MOC_NATIVE` if needed:
   ```bash
   export QT_MOC_NATIVE=$(brew --prefix qt)/bin/moc
   ```

### Local Development
For local macOS development, ensure Qt6 is installed via Homebrew:
```bash
brew install qt
# or
brew install qt@6
```

Then build normally:
```bash
./build_gui.sh
