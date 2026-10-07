# Installation

Build and install the command-line components with:

```bash
./build.sh manager
sudo ./install.sh
```

For a user-local installation:

```bash
PREFIX="$HOME/.local" ./install.sh
```

The installer installs `backup-manager`, `dvx3`, `libdvx3`, public headers, documentation, and the manual page under `PREFIX`.

The Qt6 GUI can be built and launched without a system-wide install:

```bash
./run_gui.sh
```
