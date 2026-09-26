#!/bin/bash
set -e

WORK_DIR="/home/dvx3/Documenti/Programming/Vala/Dvx3-Backup-Manager"

echo "=========================================="
echo "  CI/CD LOCAL VALIDATION SUITE"  
echo "=========================================="
echo ""

cd "$WORK_DIR"

# Validate .gitlab-ci.yml syntax
echo "[1/7] Validating .gitlab-ci.yml..."
python3 -c "import yaml; yaml.safe_load(open('.gitlab-ci.yml'))" && echo "  ✓ YAML syntax valid" || exit 1

# Check required files exist
echo ""
echo "[2/7] Checking required files..."
for f in build_all.sh .gitlab-ci.yml README.md LICENSE dvx3.vapi; do
  if [ -f "$f" ]; then
    echo "  ✓ $f exists ($(wc -l < "$f") lines)"
  else
    echo "  ✗ $f MISSING"
    exit 1
  fi
done

# Validate build script is executable
echo ""
echo "[3/7] Checking build_all.sh..."
if [ -x "./build_all.sh" ]; then
  echo "  ✓ build_all.sh is executable"
else
  chmod +x ./build_all.sh
fi

# Check dependencies locally  
echo ""
echo "[4/7] Checking local dependencies..."
PKG_CHECK_GLIB=$(pkg-config --exists glib-2.0 && echo OK || echo FAIL)
PKG_CHECK_JSON=$(pkg-config --exists json-glib-1.0 && echo OK || echo FAIL)  
PKG_CHECK_SODIUM=$(pkg-config --exists libsodium && echo OK || echo FAIL)

if [ "$PKG_CHECK_GLIB" = "OK" ]; then
  echo "  ✓ glib-2.0     : $(pkg-config --modversion glib-2.0)"
else
  echo "  ✗ glib-2.0 NOT FOUND"
fi

if [ "$PKG_CHECK_JSON" = "OK" ]; then
  echo "  ✓ json-glib    : $(pkg-config --modversion json-glib-1.0)"
else
  echo "  ✗ json-glib NOT FOUND"
fi

if [ "$PKG_CHECK_SODIUM" = "OK" ]; then
  echo "  ✓ libsodium    : $(pkg-config --modversion libsodium)"
else
  echo "  ✗ libsodium NOT FOUND"
fi

# Create release directories
echo ""
echo "[5/7] Creating release directories..."
mkdir -p Releases/linux/x86_64 Releases/macos/aarch64 Releases/macos/x86_64 Releases/windows/x86_64 .gitlab-ci-local-artifacts

# Run the actual build (limited to Linux x86_64 for speed)
echo ""
echo "[6/7] Running local build test..."
if ./build_all.sh 2>&1 | tee build-test.log; then
  echo "  ✓ Build completed successfully"
else
  echo "✗ Build failed. Check build-test.log"
fi

# Verify artifacts
echo ""
echo "[7/7] Artifact Verification:"
if [ -f "Releases/linux/x86_64/cli_backup_manager" ]; then
  ls -lh Releases/linux/x86_64/cli_backup_manager
  echo "  ✓ Linux x86_64 artifact produced"
else
  echo "⚠️  No Linux binary produced (build_all.sh may have failed)"
fi

echo ""
echo "=========================================="
echo "  VALIDATION COMPLETE"
echo "=========================================="
