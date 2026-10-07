# Architecture Overview

Dvx3 Backup Manager is architected around a **Vala core library** that provides the encryption, compression, and archive management logic. The Qt6 GUI and CLI TUI are thin wrappers around this core.

## High-Level Architecture Diagram

```
┌─────────────────────────────────────────────────────────────┐
│                      Dvx3 Backup Manager                      │
├──────────────────┬──────────────────┬────────────────────────┤
│   Vala Core Lib  │     Qt6 GUI      │       CLI TUI           │
│ (libdvx3.so)    │  (Qt6 Wrapper)   │  (ANSI Escape Codes)   │
├──────────────────┼──────────────────┼────────────────────────┤
│ • Encryption:    │ • File selection │ • Interactive menu      │
│   Argon2id KDF  │ • Drag & drop    │ • Non-interactive mode  │
│ • Compression:   │ • Preview        │ • Scripting mode        │
│   ZSTD           │ • Progress       │                         │
│ • Archive I/O:   │ • Settings UI    │                         │
│   streaming tar  │                   │                         │
└──────────────────┴──────────────────┴────────────────────────┘
         ▲                    ▲                  ▲
         └────── C API Binding (valac --capi) ────┘
```

## Core Components

### `vala/core/dvx3.vala` — The Heart of Dvx3

This is the **only** file that contains business logic:
- Encryption pipeline (Argon2id → XSalsa20-Poly1305)
- Archive format specification and I/O
- Compression via ZSTD streaming
- Password strength estimation

It uses **zero** GTK/GTK4 dependencies. It only depends on `GLib` and `Gio`, which are available on all platforms (Linux, Windows, macOS) via the same GObject introspection mechanism.

### C API Bindings (`valac --capi`)

The Vala core library is compiled with:
```bash
valac --pkg=GLib --pkg=Gio --capi=dvx3.h:dvx3.c vala/core/dvx3.vala
```

This generates `dvx3.h` and `dvx3.c`, which are then compiled into a shared/static library. This C API is what the Qt6 GUI links against, allowing any language (C/C++, Rust, Go, Python via ctypes/cffi) to use the core logic.

### CLI TUI (`vala/cli/app.vala`)

The terminal UI uses **ANSI escape codes** exclusively for rendering:
- Colors: `\x1b[38;5;N` (256-color mode)
- Cursor movement: `\x1b[A`, `\x1b[B`
- Clear screen: `\x1b[2J\x1b[H`

This means the same binary works on:
- Linux xterm/kitty/alacritty/foot/sway-term
- Windows Terminal 10+ (full ANSI support)
- macOS iTerm2 / Apple Terminal (with `defaults write com.apple.terminal enableFullAnsiSupport -bool true`)

No curses, no ncursesw, no libtinfo — just plain C stdout writes of escape sequences.

### Qt6 GUI (`gui/qt/qtdesktop/main.cpp`)

The GUI is a **thin wrapper** around the Vala core library:
- It links against `libdvx3.so` (the shared library generated from `valac --capi`)
- All encryption/compression logic is delegated to the C API
- Qt handles only UI concerns: file dialogs, progress bars, drag-and-drop

This separation means you can:
1. Build just the core library and CLI on a headless server
2. Build only the GUI for desktop users
3. Use the same compiled `libdvx3.so` in both contexts

## Cross-Platform Strategy

| Platform | Toolchain | Notes |
|----------|-----------|-------|
| Ubuntu x86_64 | native gcc/valac | Reference build |
| Linux ARM64 (Raspberry Pi) | `aarch64-linux-gnu-gcc` cross-toolchain | Same source, different compiler prefix |
| Linux ARMHF (Pi Zero) | `arm-linux-gnueabihf-gcc` cross-toolchain | 32-bit target |
| Windows x64 | MSVC + valac via Choco, or MinGW-w64 | Uses Windows native tooling |
| Windows ARM64 | MinGW-w64 `aarch64-w64-mingw32-gcc` cross-toolchain | Cross-compiled from x64 host |
| macOS Intel | XCode clang (native) | Native build on x86_64 hardware |
| macOS Silicon | XCode clang (native, ARM64) | Native build on Apple Silicon |

The key is that **the same Vala source** compiles everywhere. The only platform-specific things are:
- The C/C++ compiler prefix (`x86_64-linux-gnu-gcc` vs `arm-linux-gnueabihf-gcc`)
- The Qt backend (QPlatform::native) handles platform-native file dialogs, drag-and-drop, etc. automatically

## Security Considerations

### Password Strength Estimation

The strength meter estimates Shannon entropy:
- +1 for length ≥ 12, +1 for length ≥ 16
- +1 per character class (upper, lower, digit, symbol) → max 4 bonus points
- Dictionary word detection subtracts ~3–5 bits of estimated entropy

This is a heuristic; true security requires a password manager or cryptographically random passwords.

### Streaming Pipeline

To avoid holding large files in memory:
```
source_directory ──[tar]──► /tmp/dvx3-staging/ ──[zstd -T0]──► compressed ──[encrypt]──► archive.dvx3
```

The staging directory is cleaned up atomically at the end. On failure, partial archives are left in a `.partial` subdirectory.

## Future Work (Roadmap)

- [ ] Add Rust bindings via `bindgen` on top of the C API for high-performance embedded use cases
- [ ] Implement parallel chunking with `gio::FileOutputStream` + thread pool
- [ ] Add incremental backup mode (delta encoding between successive snapshots)
- [ ] Integrate with D-Bus daemon for system-wide scheduled backups (Epico G3 project)

## License

Dvx3 is MIT licensed. The Vala core library, C API bindings, and Qt6 GUI are all under the same license.
