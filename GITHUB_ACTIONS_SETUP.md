# GitHub Actions Setup Guide

## Overview

This repository now has a complete GitHub Actions workflow that builds the Dvx3 Backup Manager for three platforms:
- **Linux** (Ubuntu x86_64)
- **macOS** (Universal binary - Intel + Apple Silicon)
- **Windows** (x64 with MSYS2)

## What Was Fixed

### macOS Issues (Previously Documented in TODO.md)
✅ **Qt6 Installation**: Changed from generic `qt` to explicit `qt@6` package
✅ **Path Configuration**: Proper PATH setup using `$(brew --prefix qt@6)/bin`
⚠️ **Note:** On some Homebrew installs, `qt` may be installed instead of `qt@6`.
If you encounter `No such keg: /opt/homebrew/Cellar/qt@6` or similar warnings, the workflow
will try to detect `qt@6`, `qt`, or `qt6` automatically, but for local builds you can export
`QT6_PREFIX=$(brew --prefix qt)` to make it explicit to the build scripts.
✅ **MOC Detection**: Checks for `moc` in both `libexec` and `bin` directories
✅ **Environment Variables**: Sets `QT_MOC_NATIVE` and `PKG_CONFIG_PATH` correctly
✅ **DMG Creation**: Creates proper `.app` bundle with `Info.plist` and uses `hdiutil` for DMG
✅ **macdeployqt**: Automatically bundles Qt frameworks into the app
✅ **Error Handling**: Comprehensive checks and clear error messages

### Windows Issues (Newly Implemented)
✅ **MSYS2 Setup**: Uses official `msys2/setup-msys2@v2` GitHub Action
✅ **MINGW64 Toolchain**: Proper mingw-w64 compiler and tools
✅ **All Dependencies**: Installs vala, glib2, json-glib, libsodium, qt6
✅ **DLL Packaging**: Automatically copies all required runtime DLLs:
  - GLib family (libglib-2.0-0.dll, libgobject-2.0-0.dll, etc.)
  - JSON-GLib (libjson-glib-1.0-0.dll)
  - Libsodium
  - Qt6 (Qt6Core.dll, Qt6Gui.dll, Qt6Widgets.dll)
  - MinGW runtime libraries
✅ **Qt6 Plugins**: Includes platform plugins (qwindows.dll) and styles
✅ **ZIP Distribution**: Creates ready-to-run package with README

## Workflow File Location

```
.github/workflows/build.yml
```

## Workflow Triggers

The workflow runs automatically on:
- **Push to main/master/develop branches**
- **Pull requests to main/master**
- **Version tags** (e.g., `v0.0.3a101125`)
- **Manual dispatch** (via GitHub Actions UI)

## Build Jobs

### 1. Linux Build (`build-linux`)
- Runs on: `ubuntu-latest`
- Builds: CLI (`dvx3`) and GUI (`backup-manager-gui`)
- Artifacts: Executables and shared library

### 2. macOS Build (`build-macos`)
- Runs on: `macos-latest`
- Builds: Universal binary (Intel + Apple Silicon)
- Creates: `.app` bundle and `.dmg` installer
- Artifacts: DMG file and app bundle

### 3. Windows Build (`build-windows`)
- Runs on: `windows-latest` with MSYS2
- Builds: CLI (`Dvx3.exe`) and GUI (`backup-manager-gui.exe`)
- Creates: ZIP package with all DLLs
- Artifacts: ZIP file and extracted folder

### 4. Release Creation (`create-release`)
- Runs on: `ubuntu-latest`
- Triggers: Only on version tags (e.g., `v1.0.0`)
- Creates: GitHub Release with all platform artifacts

## How to Use

### Testing the Workflow

1. **Push to GitHub**:
   ```bash
   git add .github/workflows/build.yml TODO.md
   git commit -m "Add GitHub Actions workflow for multi-platform builds"
   git push origin main
   ```

2. **Check Workflow Status**:
   - Go to your repository on GitHub
   - Click on "Actions" tab
   - You should see the workflow running

3. **Download Artifacts**:
   - Click on a completed workflow run
   - Scroll down to "Artifacts" section
   - Download platform-specific builds

### Creating a Release

1. **Create and push a version tag**:
   ```bash
   git tag v0.0.3a101125
   git push origin v0.0.3a101125
   ```

2. **Automatic Release**:
   - The workflow will automatically create a GitHub Release
   - All platform artifacts will be attached
   - Release notes will be auto-generated

### Manual Workflow Trigger

1. Go to "Actions" tab on GitHub
2. Select "Multi-Platform Build" workflow
3. Click "Run workflow" button
4. Select branch and click "Run workflow"

When using `workflow_dispatch` to run the workflow manually, a new diagnostic job `publish-release-diagnostics` will run and provide further details if the publish-release job is skipped. This job prints event/ref values, lists workspaces and available artifacts, and attempts to download any artifacts for inspection.

## Build Outputs

### Linux
- `backup-manager-gui` - Qt6 GUI application
- `dvx3` - CLI tool
- `libdvx3.so` - Shared library
- `dvx3.h`, `dvx3.vapi` - Development headers

### macOS
- `Dvx3-BackupManager-macOS-{VERSION}.dmg` - Installer
- `Dvx3 Backup Manager.app` - Application bundle

### Windows
- `Dvx3-BackupManager-Windows-x64-{VERSION}.zip` - Complete package
- Contains:
  - `backup-manager-gui.exe` - GUI application
  - `Dvx3.exe` - CLI tool
  - All required DLLs
  - Qt6 plugins
  - README.txt

## Troubleshooting

### macOS Build Fails
- Check if Qt6 is properly installed: Look for "Verify Qt6 installation" step
- Verify moc was found: Check "Setup Qt6 environment" step
- Check build outputs: Look for "Verify build outputs" step
 - Use the helper to debug Qt installation on macOS/local dev: `scripts/check-qt.sh --verbose`

### Windows Build Fails
- Check MSYS2 setup: Look for "Setup MSYS2" step
- Verify dependencies: Check package installation logs
- Check DLL copying: Look for "Package Windows build" step

### Linux Build Fails
- Check dependency installation: Look for "Install dependencies" step
- Verify build scripts: Check if `build.sh` and `build_gui.sh` are executable

## Environment Variables

The workflow uses these environment variables:
- `VERSION`: Set to `0.0.3a101125` (update as needed)
- `QT6_DIR`: macOS Qt6 installation directory
- `QT_MOC_NATIVE`: Path to Qt's moc tool
- `PKG_CONFIG_PATH`: For finding Qt6 packages

### Release permissions and PAT (optional)

If your organization or repository restricts `GITHUB_TOKEN` from creating releases, you can create a Personal Access Token (PAT) and store it as a repository secret named `RELEASE_PAT`.

Required scopes for the PAT:
- `repo` for private repositories (full access to create releases and upload assets)
- `public_repo` for public repositories (lighter access may be sufficient)

How to create the PAT:
1. Go to https://github.com/settings/tokens
2. Click "Generate new token" (classic or fine-grained depending on your org policies)
3. Select the `repo` or `public_repo` scope as needed
4. Copy the token, then in your repository go to Settings → Secrets → Actions, and add a new secret named `RELEASE_PAT` with the token value

When `RELEASE_PAT` is set, the workflow will use it for creating and uploading releases; otherwise it will fallback to `GITHUB_TOKEN`. The workflow will print a message indicating which token type is used for the publish step.

Additional troubleshooting steps:
- Check your repository's Actions permissions: Go to Settings → Actions → General and make sure that GitHub Actions are allowed to create releases in your organization or repository.
- If the workflow run originates from a fork, `GITHUB_TOKEN` may not have write permissions; use `workflow_dispatch` or an internal job to test.

Token verification helper
-------------------------
For convenience, `scripts/verify-release-token.sh` checks whether your PAT or `GITHUB_TOKEN` has permission to access the repository and the necessary OAuth scopes. The script prints the `X-OAuth-Scopes` header and verifies the token can access the repository. You can also use `--create-test` to attempt a temporary tag creation (this requires a token with the `repo` scope).

Example:
```bash
# Check default token env vars
./scripts/verify-release-token.sh --repo $(git remote get-url origin | sed -E 's#.*[:/]([^/]+/[^/.]+)(\.git)?$#\1#')

# Explicit PAT and repo
./scripts/verify-release-token.sh --token "<RELEASE_PAT>" --repo tadaka9/Dvx3-Backup-Manager --verbose

# Attempt to create a test tag (will be deleted) - requires repo write scope
./scripts/verify-release-token.sh --token "<RELEASE_PAT>" --repo tadaka9/Dvx3-Backup-Manager --create-test
```

CI Token preflight
------------------
A CI preflight job titled `verify-release-token` now runs automatically for releases and checks that the secret token (either `RELEASE_PAT` or `GITHUB_TOKEN`) has the necessary permissions to create releases and tags. If the token validation fails, the publish step will be blocked and helpful logs will appear in the Action run.

### Verify token scopes locally

If you created a `RELEASE_PAT`, you can verify the token's scopes locally with curl:

```bash
curl -I -H "Authorization: token <YOUR_PAT>" https://api.github.com | egrep -i "x-oauth-scopes|x-accepted-oauth-scopes"
```

This prints the scopes that will be accessible to the token; make sure `repo` or `public_repo` is present as appropriate.

## Next Steps

1. ✅ Workflow created and documented
2. ⏳ Push to GitHub to trigger first build
3. ⏳ Test all three platforms
4. ⏳ Verify artifacts work correctly
5. ⏳ Create a version tag to test release creation
6. ⏳ Download and test packaged applications

## Publish-only (upload artifacts from a prior run)

If you have artifacts uploaded by a previous workflow run and you want to publish them to a GitHub Release without re-running all build jobs, you can use the `publish_only` workflow input combined with `publish_artifacts_run_id`.

Steps:

1. Find the run id that produced the artifacts you want to publish:
```bash
gh run list --workflow 'Build, Package & Release'
# Note the 'Run ID' for the build run that uploaded the artifacts
```
2. Run the workflow in publish-only mode to download artifacts from that run and publish them to a release:
```bash
gh workflow run 'Build, Package & Release' --ref clean-version \
   --field publish_only=true \
   --field publish_artifacts_run_id=<RUN_ID> \
   --field release_tag=vX.Y.Z
```

Notes:
- `publish_artifacts_run_id` is required when `publish_only=true` as the workflow needs to know which run to fetch artifacts from.
- If the release tag doesn't exist and you want the workflow to create it, set `create_tag_if_missing=true` and provide a `RELEASE_PAT` secret with `repo` scope. Otherwise, ensure the tag exists before running the workflow.
- The `publish-only` job verifies checksums and validates the tag before uploading artifacts to the release. If verification fails, the publish step will be blocked.

### Quick UI-friendly example (GitHub CLI)
Use the GitHub CLI (`gh`) to dispatch the publish-only workflow in a single command:

```bash
# Replace <RUN_ID> (the build run ID that produced the artifacts) and vX.Y.Z with your tag
gh workflow run 'Build, Package & Release' --ref clean-version \
   --field publish_only=true \
   --field publish_artifacts_run_id=<RUN_ID> \
   --field release_tag=vX.Y.Z \
   --field create_tag_if_missing=true \
   --field strict_artifact_checks=true
```

Notes:
- Use `gh run list --workflow 'Build, Package & Release' --limit 20` to find runs that uploaded artifacts.
- Validate artifacts after running using `gh run view <NEW_RUN_ID> --log`.

### Common issues and fixes
- No runs appear after dispatching:
   - Ensure you used the correct workflow name (`Build, Package & Release`) or file name (`build.yml`) in `gh run list`.
   - You can also list runs for the workflow file name directly:
      ```bash
      gh run list --workflow build.yml --limit 20
      ```

- Tag creation & push failures ("refusing to allow an OAuth App to create or update workflow ... without `workflow` scope"):
   - When pushing tags or changes that update `.github/workflows/*`, GitHub may reject OAuth token push requests that don't have the `workflow` scope.
   - To push tags reliably, either:
      - Use SSH remote: `git remote set-url origin git@github.com:<owner>/<repo>.git` and `git push origin vX.Y.Z`, or
      - Create a PAT with `repo` and `workflow` scopes and use it (or `gh auth login` with the PAT) to authenticate.
   - Avoid typos in tag names (e.g., `v0.0.3-alpha112725` vs `v0.0.0.3-alpha112725`).
   - To avoid needing a workflow-scoped token to push, prefer using SSH: see `scripts/push-via-ssh.sh` that converts your origin to SSH and pushes the provided refs.
   - If you prefer HTTPS / PAT, make sure the token includes the `workflow` scope and re-authenticate via `gh auth login --with-token` or update your credential helper for git.

- Token scope & 403 errors when creating releases:
   - Use `scripts/verify-release-token.sh --token <PAT> --repo <owner/repo> --verbose --create-test` to verify the token's scopes and validate that it can create tags/releases.

### Alternative: Create release directly using `gh`
If you have the built artifacts locally (or zipped), you can create a release directly with `gh` instead of dispatching the workflow:

```bash
gh release create vX.Y.Z ./Releases/* --title "vX.Y.Z" --notes "Release notes..."
```

This avoids workflow restrictions during tag pushes (requires PAT or authenticated `gh` with correct scopes).

## Support

If you encounter issues:
1. Check the workflow logs in GitHub Actions
2. Review the specific step that failed
3. Check the TODO.md for known issues
4. Verify all build scripts are present and executable

## Files Modified/Created

- ✅ `.github/workflows/build.yml` - Main workflow file (NEW)
- ✅ `TODO.md` - Updated with Windows fixes and workflow status
- ✅ `GITHUB_ACTIONS_SETUP.md` - This documentation (NEW)

## Comparison with GitLab CI

The GitHub Actions workflow is equivalent to the GitLab CI configuration but:
- Uses GitHub-specific actions (checkout@v4, upload-artifact@v4, etc.)
- Uses MSYS2 action for Windows instead of shell runner
- Uses native macOS runner instead of shell runner
- Automatically creates releases on tags
- Provides better artifact management
