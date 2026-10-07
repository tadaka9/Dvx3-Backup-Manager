# Cleanup report

## Canonical architecture

- Core: `libdvx3.vala`
- CLI: `dvx3-cli.vala`
- Interactive manager: `backup-manager.cpp` / `backup-manager.hpp`, consuming the Vala core API
- Desktop GUI: Qt6, `gui/qt/qtdesktop/main.cpp`
- Build entry point: `build.sh`
- CI: `.github/workflows/ci.yml`

## Removed

- Git history and local tool state from the distributable archive
- Generated C and binary artifacts (`main.c`, `dvx3-cpp`, build trees, release trees)
- Placeholder `main.py`
- Legacy monolithic `main.vala`, superseded by `libdvx3.vala` + `dvx3-cli.vala`
- Legacy GTK GUI and duplicate Qt5/Qt/qmake implementations
- Incomplete C++ compression/encryption experiments with missing headers/placeholder logic
- Broken scheduler prototype
- Duplicate GitLab/local CI infrastructure
- Broken/obsolete build helper scripts
- Stale AppImage/Windows packaging paths and truncated Dockerfile
- Historical CI/status documentation

## Strengthened

- One build entry point with `core`, `manager`, `gui`, `all`, and `clean` targets
- All build output goes under `build/`
- Qt6 CMake uses AUTOMOC/AUTORCC consistently
- Fixed invalid Qt table widget assignment and missing Qt includes
- Installer now invokes the canonical build and installs from `build/`
- Tests use the canonical build outputs
- One GitHub CI workflow matches the local build
- `.gitignore` is short and artifact-oriented instead of enumerating system libraries

## Validation

- Shell scripts pass `bash -n` syntax validation.
- No generated binaries/build trees are included.
- CMake reaches Qt6 dependency discovery correctly; full GUI compilation was not possible in the cleanup environment because Qt6 development packages are not installed there.
- Full Vala compilation was not possible in the cleanup environment because `valac` and its development dependencies are not installed there.
