# Packaging Qt GUI (AppImage) with QtWebEngine

This guide explains how to create an AppImage for the `backup-manager-gui` that includes Qt and the Qt WebEngine resources so the embedded Web UI works on most Linux distros.

Prerequisites
- Linux host with Qt6 development tools installed (or you can run using the system Qt libs).
- `linuxdeployqt` (AppImage) and `appimagetool` available in your PATH.
- If you want to build a reproducible AppImage, install the `linuxdeployqt` and `appimagetool` or use a CI runner.

Quick steps
1. Build the GUI:
```bash
./build_gui.sh
```
2. Run the bundling script:
```bash
chmod +x pack-appimage.sh
./pack-appimage.sh
```
This script will:
- Build the GUI (calls `./build_gui.sh`)
- Create an AppDir and copy the binary and widget resources
- Auto-detect and copy the QtWebEngineProcess binary, qtwebengine resources pak and locales if they exist on your system
- Create an `AppRun` wrapper script that sets `QTWEBENGINEPROCESS_PATH` and `QTWEBENGINE_RESOURCES_PATH` and `QT_QPA_PLATFORM_PLUGIN_PATH` so the AppImage can find all required files at runtime
- Run `linuxdeployqt` to bundle the Qt libs and produce the AppImage.

Notes and troubleshooting
- If `linuxdeployqt` or `appimagetool` aren't installed, the script will exit with a helpful message. Use the official releases at https://github.com/probonopd/linuxdeployqt/releases and https://github.com/AppImage/AppImageKit/releases.
- The script attempts to detect `QtWebEngineProcess`, `qtwebengine_resources.pak`, and `qtwebengine_locales` on common system paths and via `qmake -query` where available. If your Qt installation is in a custom location, set the following environment variables before running the script: `QT_INSTALL_BINS`, `QT_INSTALL_PREFIX` or set `QTWEBENGINEPROCESS_PATH` and `QTWEBENGINE_RESOURCES_PATH` manually.
- If the AppImage launches but the WebView doesn't appear, ensure your AppImage contains `qtwebengine_resources.pak` under `usr/share/qt6/resources/` inside the AppImage and the `QtWebEngineProcess` binary is present under `usr/libexec/qt6/` or `usr/bin/` inside the AppImage. The `AppRun` wrapper sets env vars pointing to those locations.

Advanced/CI packaging
- For CI, download `linuxdeployqt` and `appimagetool` during the job and run the script to produce an AppImage artifact.
- To support multiple desktop targets and ensure correct OpenGL/GLX runtime, consider enabling the `QT_OPENGL` or `QT_QUICK_BACKEND` env vars in the wrapper or investigate bundling ANGLE or software rasterizer as a fallback.

Manual bundling steps (if script needs adjustments)
1. Create AppDir with the binary in `AppDir/usr/bin`.
2. Copy these items into AppDir:
  - `QtWebEngineProcess` into `AppDir/usr/libexec/qt6/`.
  - `qtwebengine_resources.pak` into `AppDir/usr/share/qt6/resources/`.
  - `qtwebengine_locales/*` into `AppDir/usr/share/qt6/translations/qtwebengine_locales/`.
3. Write an `AppRun` wrapper to export `QTWEBENGINEPROCESS_PATH` and `QTWEBENGINE_RESOURCES_PATH` to point to the files in AppDir, then `exec` your binary.
4. Run `linuxdeployqt` on the binary with `-appimage` to generate the AppImage.

If you want, I can add a GH Actions workflow to build this AppImage for you automatically on pushes/tag builds.

EOF
