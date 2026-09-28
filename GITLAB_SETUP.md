# GitLab CI Setup Guide

## Overview

This repository now includes a complete `.gitlab-ci.yml` pipeline that builds Dvx3 Backup Manager across all platforms:

```
┌─────────────────────────────────────────────────────────┐
│  GitHub Actions (already working)                        │
├─────────────────────────────────────────────────────────┤
│  Linux x86_64  →  macOS ARM64   →  macOS Intel         │
│  Linux ARM64   →  Windows       →  Release on tag      │
└─────────────────────────────────────────────────────────┘
```

---

## Step-by-Step Setup

### 1. Create Your GitLab Project

Visit: https://gitlab.com/users/authenticated/project/new

| Setting | Value |
|---------|-------|
| **Name** | `dvx3-backup-manager` |
| **Namespace** | Your username (or a group) |
| **Visibility** | Private (recommended for source code) |
| **Initialize with README** | ✅ Yes |

### 2. Clone the Repository on GitLab

```bash
git clone https://gitlab.com/YOUR_USER/dvx3-backup-manager.git
cd dvx3-backup-manager
```

### 3. Configure Your Personal Access Token (PAT)

1. Go to: https://gitlab.com/profile/personal_access_tokens
2. Click **"New token"**
3. Set the following settings:
   - **Name:** `Dvx3-Backup-Manager CI`
   - **Expiry date:** Leave blank (no expiry, or set as needed)
   - **Scopes:** Check ✅ `api`, ✅ `read_registry`
4. Click **"Create personal access token"**
5. **Copy the token** — you won't be able to see it again!

### 4. Add GitLab as a Remote and Push

```bash
cd /home/dvx3/Documenti/Programming/Vala/Dvx3-Backup-Manager

# Add GitLab remote (replace with your project path)
git remote add gitlab https://gitlab.com/YOUR_USER/dvx3-backup-manager.git

# Verify the remote is configured correctly
git remote -v

# Push to GitLab
git push --set-upstream gitlab main
```

### 5. Trigger the CI Pipeline

#### Option A: Via Web UI (Simplest)

1. Go to your project page on GitLab
2. Navigate to **Pipelines** tab
3. Click **"Run pipeline"**
4. Select branch `main` and click **"Run"**

#### Option B: Via API Script (Automated)

```bash
# Set your token once for the session
export GITLAB_API_TOKEN="glpat-xxxxxxxxxxxxxxxxxxxx"

# Trigger CI on main branch
./scripts/gitlab-ci-trigger.sh https://gitlab.com/YOUR_USER/dvx3-backup-manager.git main
```

#### Option C: Direct API Call

```bash
curl -X POST \
  -H "PRIVATE-TOKEN: glpat-xxxxxxxxxxxxxxxxxxxx" \
  --data '{"ref":"main"}' \
  https://gitlab.com/api/v4/projects/YOUR_USER%2Fd vx3-backup-manager/pipeline
```

### 6. Monitor the Pipeline

Visit your project's **Pipelines** tab and watch the jobs run:

| Job | Expected Duration | Status Indicator |
|-----|-------------------|-----------------|
| `validate-yaml` | ~1s | ✓ if YAML is valid |
| `build-linux-x86_64` | ~3–5 min | Watch for errors in `build.log` |
| `build-linux-arm64` | ~3–5 min | Uses ubuntu-24.04-arm runner |
| `test-cli-binary` | ~1 min | Verifies roundtrip encryption/decryption |

---

## Understanding the `.gitlab-ci.yml` Stages

```yaml
stages:
  - validate    # YAML syntax check (fast, always passes if valid)
  - build-linux # x86_64 + ARM64 Linux builds
  - build-macos # Intel + Apple Silicon macOS builds  
  - build-windows # MSYS2 Windows build
  - release     # Auto-triggers on v*.*.* tag pushes
```

### Key Configuration Details

| Feature | Configuration |
|---------|--------------|
| **Image** | `valac/vala:0.56.2-full` (pre-installed Vala + GCC) |
| **Artifacts retention** | 7 days (`expire_in: 1 week`) |
| **Auto-release** | Triggers on tags matching `v\d+\.\d+\.\d+` |
| **Parallel jobs** | Linux x86_64 and arm64 build in parallel (faster!) |

---

## Troubleshooting

### "Device or resource busy" / Authentication errors

```bash
# The script needs proper permissions
export GITLAB_API_TOKEN="glpat-xxxxxxxxxxxxxxxxxxxx"
./scripts/gitlab-ci-trigger.sh https://gitlab.com/YOUR_USER/dvx3-backup-manager.git main
```

### "Pipeline failed" — Check the logs

1. Go to **Pipelines** → Click on your pipeline ID
2. Look for red ❌ icons next to jobs
3. Click the job name, then scroll to **"Artifacts"** at the bottom
4. Download and inspect `build.log` for the full error output

### Common Errors

| Error | Cause | Fix |
|-------|-------|-----|
| `Package glib-2.0-dev not found` | Missing system dependencies on runner | Runner should use Docker image — if custom, add to `.gitlab-ci.yml` |
| `No such file or directory: build_all.sh` | File path issue in runner | Ensure the repo is cloned into a writable CI directory (`.gitlab-ci-local-artifacts`) |
| `Permission denied` | Token has insufficient scope | Revoke and recreate PAT with `api` + `read_registry` scopes |

---

## Manual Local Testing (No Docker Needed)

If you want to test the build locally without Docker:

```bash
# Install dependencies on your machine
sudo apt install valac gcc pkg-config libglib2.0-dev \
  libgio-2.0-dev libjson-glib-dev libsodium-dev \
  gir1.2-gtk-4.0 libgtk-4-dev zip dos2unix

# Run the validation suite
./test-cicd-validation/validate-ci.sh
```

This validates:
- ✅ YAML syntax of `.gitlab-ci.yml`
- ✅ All required source files exist
- ✅ Build script is executable
- ✅ Dependencies are installed locally
- ✅ Full build produces a working binary
- ✅ Binary successfully encrypts and decrypts test data

---

## Next Steps After First Push

1. **First push:** The CI will run automatically on `push` events to `main`, `master`, or `develop`.
2. **Tag v1.0.0** when ready:
   ```bash
   git tag -a v1.0.0 -m "Initial stable release"
   git push origin v1.0.0
   ```
3. The `release-on-tag` job will automatically create a draft release on GitHub/GitLab with all artifacts attached.

---

## Security Notes

- **Never commit your PAT** — the script reads from `GITLAB_API_TOKEN` environment variable only
- The token is stored in GitLab's session, not written to disk or git history
- For production use, consider setting up a **GitLab CI/CD Variable** for the token (Settings → CI/CD → Variables)

---

## Support & Help

If you encounter issues:

1. Check the pipeline logs first — 90% of errors are visible there
2. Verify your Docker image can pull from `valac/vala:0.56.2-full` (may need manual add to GitLab's allowed registries)
3. Ensure the repository has **CI/CD enabled** (most projects have it by default, but check project settings)
