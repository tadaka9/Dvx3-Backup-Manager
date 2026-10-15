# Contributing to DVX3 Backup Manager

Thank you for your interest in contributing! This document outlines the contribution guidelines, development workflow, and coding standards.

## Code of Conduct

Please be kind and respectful. We aim to create a welcoming environment for all contributors regardless of background or experience level.

## How to Contribute

### 1. Reporting Bugs

If you find a bug, please file an issue on GitHub with:
- A clear description of the problem
- Steps to reproduce (if applicable)
- Expected vs actual behavior
- Your environment (OS, Vala version, GCC version)

### 2. Suggesting Features

Open an issue describing your feature idea. Include:
- Use case and motivation
- Proposed API design
- Any relevant references or examples

### 3. Submitting Pull Requests

1. Fork the repository
2. Create a branch from `main`: `git checkout -b feature/amazing-feature`
3. Make your changes, following the coding standards below
4. Write or update tests if applicable
5. Commit with conventional commit message: `feat(core): add X feature`
6. Push to GitHub and open a Pull Request

## Coding Standards

### Vala Style Guide

- Use 2-space indentation (no tabs)
- Maximum line length: 100 characters
- Prefer descriptive names over abbreviations
- Document public API functions with `/** ... */` comments
- Use `//` for inline comments; avoid overly verbose comments that restate the code

### Memory Management

- Prefer stack allocation where possible (automatic cleanup)
- For heap allocations, always pair `new GLib.Bytes()` with `.close()` or RAII patterns
- Avoid holding references to large objects longer than necessary
- Use `try`/`catch (Error e)` blocks for error handling; rethrow wrapped errors when appropriate

### Error Handling

```vala
public void some_method() throws Error {
    if (!file.query_exists()) {
        throw new IOError.NO_SUCH_FILE("File not found: %s", path);
    }
    var data = file.read();
    // ... process data
}
```

### Thread Safety

- Use `Thread.spawn()` for background work, never blocking threads in GUI code
- Protect shared mutable state with locks or use thread-local storage
- Prefer immutable data structures where possible

## Code Review Process

All contributions are reviewed by maintainers. Reviews may request:
- Additional test coverage
- Refactoring of complex logic
- Documentation updates
- Security review (for cryptographic operations)

PRs will be merged once all CI checks pass and the review is approved.

## Build & Test Locally

```bash
# Install dependencies
sudo apt install valac glib-2.0-dev libgtk-4-dev gcc make pkg-config

# Build
make all

# Run tests
make test

# Clean build artifacts
make clean
```

## License

By contributing, you agree that your contributions will be licensed under the MIT License, consistent with this project's license.