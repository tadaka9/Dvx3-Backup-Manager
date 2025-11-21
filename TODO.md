# TODO List

## Completed ✅

### Build System Fixes
- [x] **Windows MOC Detection** - Fixed moc not found error on Windows/MSYS2 builds
  - Added MSYS2-specific paths to `build_gui.sh`
  - Enhanced GitHub Actions workflow verification
  - Documented in `WINDOWS_MOC_FIX.md`

- [x] **macOS MOC Detection** - Fixed moc not found error on macOS/Homebrew builds
  - Added Homebrew-specific paths for both Apple Silicon and Intel Macs
  - Enhanced GitHub Actions workflow to handle both `qt` and `qt@6` packages
  - Added fallback checks for Homebrew bin directories in workflow verification
  - Documented in `MACOS_MOC_FIX.md`

### Multi-Platform Support
- [x] Linux (Ubuntu) builds working
- [x] Windows (MSYS2/MINGW64) builds working
- [x] macOS (Apple Silicon & Intel) builds working

## In Progress 🔄

### Documentation
- [ ] Update main README.md with build status badges
- [ ] Add troubleshooting section to README.md

### Features
- [ ] Add automated testing for CLI
- [ ] Add automated testing for GUI
- [ ] Implement backup verification feature
- [ ] Add progress indicators for long operations

## Planned 📋

### Enhancements
- [ ] Add support for incremental backups
- [ ] Implement backup scheduling
- [ ] Add cloud storage integration (S3, Azure, etc.)
- [ ] Create configuration file support
- [ ] Add backup compression options

### Platform Support
- [ ] Test on Raspberry Pi (ARM)
- [ ] Add FreeBSD support
- [ ] Test on older macOS versions

### CI/CD
- [ ] Add automated release creation on version tags
- [ ] Implement code signing for macOS builds
- [ ] Add Windows code signing
- [ ] Create AppImage for Linux

### GUI Improvements
- [ ] Add dark mode support
- [ ] Implement drag-and-drop for file selection
- [ ] Add backup history viewer
- [ ] Create settings/preferences dialog

## Known Issues 🐛

None currently reported.

## Notes 📝

- All three major platforms (Linux, Windows, macOS) now have working builds
- MOC detection is robust across different installation methods
- GitHub Actions workflow successfully builds and packages for all platforms
- DMG creation for macOS includes proper app bundle with Qt frameworks
- Windows builds include all necessary DLLs in the package
