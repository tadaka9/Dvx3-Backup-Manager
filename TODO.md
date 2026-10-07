# Remaining work

- Run the native Linux ARM64, macOS Intel/ARM64 and Windows x64 candidate CI jobs.
- Validate vendor Razor binaries and concrete reversible XTool/SREP/LOLZ adapters.
- Add versioned codec profile portability and automated compatibility fixtures.
- Import legacy manager configuration/history with explicit diagnostics for ambiguous values.
- Add password input without shell history/environment exposure to the manager/CLI.
- Add cooperative cancellation and manual desktop GUI interaction tests.
- Reduce plaintext disk staging after portable backends have equivalent error guarantees.
- Strengthen extraction isolation and authenticated framing in a future archive version.
- Define platform metadata restoration guarantees (ACLs, symlinks, ownership, Windows paths).
- Implement actual packaging scripts/dependency bundling before advertising release packages.
- Add native ARMHF / Windows ARM64 runners only with testable toolchains.
- Define scheduler integration; no daemon is currently implemented.
