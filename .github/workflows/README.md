# GitHub Actions Workflows

## Workflow Overview

| Workflow | Trigger | Purpose | Status |
|----------|---------|---------|--------|
| `build.yml` | Push to branches/tags, PRs | Cross-platform build (Linux/macOS/Windows) | ✅ Active |
| `pre-push-validate.yml` | Push to main/master | Syntax validation before merge | ✅ New |

---

## Building Locally for Development

### Prerequisites

```bash
# Ubuntu/Debian
sudo apt install valac gcc pkg-config zip \
  libglib2.0-dev libgio-2.0-dev libjson-glib-dev \
  libsodium-dev gir1.2-gtk-4.0 libgtk-4-dev

# macOS (Homebrew)
brew install valac glib cmake zip dos2unix pkg-config gtk4
```

### Running Workflows Locally

```bash
# Validate workflow YAML syntax
python3 -c "import yaml; yaml.safe_load(open('.github/workflows/build.yml'))"

# Run pre-commit checks
pip install pre-commit
pre-commit run --all-files
```

---

## Architecture

```
.github/
├── workflows/
│   ├── build.yml                 → Cross-platform build matrix
│   └── pre-push-validate.yml     → Pre-merge validation
├── CIBUILDING.md                 → Full CI documentation
└── README.md                     ← You are here
```

---

## Build Matrix

### Linux (Ubuntu)
| Job | Runner | Tests |
|-----|--------|-------|
| x86_64 | `ubuntu-latest` | ✅ |
| aarch64 | `ubuntu-24.04-arm` | ✅ |

### macOS
| Job | OS | Notes |
|-----|----|-------|
| x86_64 | `macos-13` (Intel) | Requires Homebrew glib for gio-unix-2.0.pc |
| aarch64 | `macos-latest` (Apple Silicon) | Requires Homebrew glib for gio-unix-2.0.pc |

### Windows (MSYS2)
| Job | MSYS2 Profile | Notes |
|-----|---------------|-------|
| x86_64 | MINGW64 | Native 64-bit build |
| arm64 | CLANGARM64 | ARM64 via WSL2/MSYS2 |

---

## Artifact Storage

Artifacts are retained for **30 days** by default:

```bash
# Download artifacts after CI runs
gh run download -r tadaka9/Dvx3-Backup-Manager --latest \
  --pattern "Dvx3-Backup-Manager-linux-x86_64.tar.gz"
```

---

## Security Notes

- **GPG Signing**: Configure `GPG_KEY_ID` in GitHub Secrets for artifact signing (optional)
- **Secrets Required**: None currently required; GPG key is optional
- **No external API calls** from workflows except release tagging

---

## Updating This File

When modifying this workflow:

1. Update the trigger conditions (`on:` section)
2. Add new jobs under `jobs:` with proper `if:` guards for concurrency control
3. Test locally first with `python3 -c "import yaml; yaml.safe_load(open('build.yml'))"`
4. Run on a non-production branch before merging to main

---

## CI/CD Pipeline Flow

```
Push → Dispatch → Validate YAML → Build (Matrix) → Upload Artifacts
                                    ↓
                          Tag Push → Auto-release → Release Page
```
