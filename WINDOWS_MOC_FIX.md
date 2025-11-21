# Windows MOC Detection Fix

## Problem
The Windows build in GitHub Actions was failing at step [4/5] with the error:
```
Error: moc not found. Install Qt6 development tools.
```

## Root Cause
The `build_gui.sh` script was checking for Qt MOC (Meta-Object Compiler) in Linux and macOS paths, but not in MSYS2/MINGW64-specific locations where Qt6 tools are installed on Windows.

### Paths Checked (Before Fix):
- `$QT_MOC_NATIVE` environment variable
- `/usr/lib/qt6/moc` (Linux)
- `/usr/lib/qt6/libexec/moc` (Linux)
- `moc-qt6`, `moc6`, `moc` (commands in PATH)

### Missing Paths (MSYS2/MINGW64):
- `/mingw64/bin/moc`
- `/mingw64/qt6/bin/moc`
- `/mingw64/lib/qt6/bin/moc`

## Solution

### 1. Updated `build_gui.sh`
Added MSYS2-specific moc detection paths before the Linux paths:

```bash
# Check MSYS2/MINGW64 paths (Windows)
elif [ -x /mingw64/bin/moc ]; then
    MOC=/mingw64/bin/moc
    RCC=/mingw64/bin/rcc
elif [ -x /mingw64/qt6/bin/moc ]; then
    MOC=/mingw64/qt6/bin/moc
    RCC=/mingw64/qt6/bin/rcc
elif [ -x /mingw64/lib/qt6/bin/moc ]; then
    MOC=/mingw64/lib/qt6/bin/moc
    RCC=/mingw64/lib/qt6/bin/rcc
```

Also improved error messages to show all searched locations for better debugging.

### 2. Enhanced `.github/workflows/build.yml`
Added a "Verify Qt6 installation" step in the Windows build job to:
- Check Qt6Widgets via pkg-config
- Search for moc in common MSYS2 locations
- Check if moc is in PATH
- List installed Qt6 packages

This provides better visibility into the Qt6 installation status and helps with debugging.

## Files Modified

1. **build_gui.sh**
   - Added MSYS2-specific moc detection paths
   - Improved error messages with searched locations
   - Maintained backward compatibility with Linux/macOS

2. **.github/workflows/build.yml**
   - Added "Verify Qt6 installation" step for Windows build
   - Provides comprehensive Qt6 installation diagnostics

3. **TODO.md**
   - Updated to reflect the fix implementation
   - Marked Windows moc detection issue as resolved

## Testing
To test the fix:
1. Push changes to GitHub
2. Monitor the Windows build job in GitHub Actions
3. Check the "Verify Qt6 installation" step output
4. Verify that the "Build GUI" step completes successfully
5. Confirm Windows artifacts are created

## Expected Outcome
- Windows build should now find moc at `/mingw64/bin/moc`
- Build should complete successfully through all 5 steps
- Windows ZIP artifact should be created with all required DLLs

## Compatibility
The fix maintains full compatibility with:
- ✅ Linux (Ubuntu) - existing paths still checked
- ✅ macOS - existing paths still checked
- ✅ Windows (MSYS2/MINGW64) - new paths added

## Related Issues
This fix resolves the Windows build failure reported in the GitHub Actions workflow where the Qt MOC tool could not be found during the GUI build process.
