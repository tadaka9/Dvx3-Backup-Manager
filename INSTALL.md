# Development installation

Read [BUILD.md](BUILD.md) for dependencies/platform status. You can run directly
from `build/bin/` on every configured native toolchain.

On Linux/macOS, `install.sh` builds and installs CLI, Vala manager, static core,
generated C header and C++ wrapper plus documentation. Example without root:

```sh
PREFIX="$HOME/.local" ./install.sh
PREFIX="$HOME/.local" ./uninstall.sh
```

The default prefix is `/usr/local` and needs the appropriate filesystem permissions.
No automatic privilege escalation is performed. The GUI and runtime dependencies
are not bundled. Uninstall preserves user configuration and archives.
For end users, CI publishes DEB, RPM and AppImage on Linux; a portable ZIP and
MSI on Windows x64; and zipped app bundles plus PKG installers on macOS Intel and
Apple Silicon. The POSIX script above remains intended for development.

Compression programs remain external. Install the tools needed by the selected
codec. Current MSI and PKG development artifacts have no commercial signing
identity, so the operating system may show a trust warning.
