# 🚀 Continuous Integration with GitLab CI/CD

## Quick Start

```bash
# 1. Set your token (run once per session)
export GITLAB_API_TOKEN="glpat-xxxxxxxxxxxxxxxxxxxx"

# 2. Trigger the pipeline
./scripts/gitlab-ci-trigger.sh https://gitlab.com/YOUR_USER/dvx3-backup-manager.git main
```

## Pipeline Architecture

```mermaid
graph TD
    A[Push to Branch] --> B{Stage: Validate}
    B -->|Valid YAML | C{Build Linux x86_64}
    B -->|Invalid| D[❌ Stop]
    C --> E{Build Linux ARM64}
    E --> F{Build macOS Intel}
    F --> G{Build macOS ARM64}
    G --> H{Build Windows MSYS2}
    H --> I[All Passed?]
    I -->|Yes| J[Stage: Test]
    J --> K[Roundtrip Encrypt/Decrypt]
    K --> L{Tag Push?}
    L -->|v*.x.x| M[Create Release Draft]
    L -->|No| N[✅ All Done]
```

## Platform Coverage

- **Linux x86_64** — Ubuntu latest (default runner)
- **Linux ARM64** — ubuntu-24.04-arm (Raspberry Pi, M1/M2 Macs with Linux)
- **macOS Intel** — macOS-latest (x86_64 runners)
- **macOS Apple Silicon** — macOS-15 (ARM64 runners)  
- **Windows x86_64** — windows-latest with MSYS2 MINGW64 toolchain

## Auto-Release on Tag Push

```bash
# Push a tag → automatic release creation
git tag -a v1.0.0 -m "Stable release 1.0.0"
git push origin v1.0.0
```

The pipeline will automatically:
1. Build all platform binaries
2. Attach them as release assets
3. Generate formatted release notes from `RELEASE_NOTES_V1.0.0.md`

## Troubleshooting

See [GITLAB_SETUP.md](./GITLAB_SETUP.md) for detailed troubleshooting guide.
