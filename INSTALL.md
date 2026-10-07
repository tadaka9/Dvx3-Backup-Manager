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
On Windows use MSYS2 UCRT64 and build/bin directly; this installer is POSIX-only.
No DEB/RPM/AppImage/DMG/MSI/NSIS packaging is implemented.
