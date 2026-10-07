# Building Dvx3 Backup Manager

The repository has one canonical build entry point: `build.sh`.

## Dependencies (Debian/Ubuntu)

```bash
sudo apt-get update
sudo apt-get install -y build-essential valac pkg-config cmake qt6-base-dev \
  libglib2.0-dev libjson-glib-dev libsodium-dev zstd
```

## Targets

```bash
./build.sh core      # Vala libdvx3 + dvx3 CLI
./build.sh manager   # core + C++ backup-manager
./build.sh gui       # Qt6 desktop GUI
./build.sh all       # manager + GUI
./build.sh clean     # remove build/
```

All generated files and binaries are written below `build/`.
Generated C/Vala/Qt artifacts are not source files and must not be committed.

## Tests

```bash
./scripts/run-tests.sh
```

## CI

`.github/workflows/ci.yml` performs the canonical Linux build and tests the same entry points used locally.
