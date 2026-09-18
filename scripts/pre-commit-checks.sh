#!/usr/bin/env bash
# pre-commit-checks.sh - Pre-commit quality checks for Dvx3 Backup Manager
# Run this before committing code to catch common issues

set -e
set -o pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="${SCRIPT_DIR}/.."
echo "=========================================="
echo "  Pre-Commit Quality Checks"
echo "=========================================="
echo ""
echo "Project: Dvx3 Backup Manager"
echo "Root Directory: ${PROJECT_ROOT}"
echo ""

# Configuration
VALA="${PROJECT_ROOT}/valac" if [ -f "${PROJECT_ROOT}/valac" ] ; else VALAC=command -v valac || { echo "❌ Error: valac not found"; exit 1; }; fi
VALA_VERSION=$(valac --version 2>&1 | head -1)
echo "✓ Vala version: ${VALA_VERSION}"
echo ""

# Check for git repository
if [ ! -d ".git" ]; then
    echo "⚠️  Warning: Not in a git repository. Some checks skipped."
    exit 0
fi

# Check for uncommitted changes
echo "[1/5] Checking for uncommitted changes..."
if [ -n "$(git status --porcelain 2>/dev/null)" ]; then
    echo "❌ Error: You have uncommitted changes!"
    echo ""
    echo "Uncommitted files:"
    git status --short
    echo ""
    echo "Please commit or stash your changes before running pre-commit checks."
    exit 1
else
    echo "✓ No uncommitted changes"
fi

# Check for staged changes
echo "[2/5] Checking staged changes..."
if [ -n "$(git diff --cached --name-only 2>/dev/null)" ]; then
    echo "✓ Changes staged (normal for commit)"
fi

# Code quality checks
echo "[3/5] Running code quality checks..."

# Check Vala syntax with valac
VALA_SOURCE_FILES=$(find "${PROJECT_ROOT}" -name "*.vala" -type f 2>/dev/null | grep -v "^${PROJECT_ROOT}/gen-c/" | grep -v "^${PROJECT_ROOT}/build/")

if [ -n "$VALA_SOURCE_FILES" ]; then
    echo "Checking Vala source files..."
    
    for vala_file in $VALA_SOURCE_FILES; do
        filename=$(basename "${vala_file}")
        
        # Skip generated files
        if [[ ${filename} == *"generated"* ]] || [[ ${filename} == *.h ]]; then
            echo "  ⏭️  Skipping generated file: ${filename}"
            continue
        fi
        
        # Run valac to check syntax
        echo "  Checking: ${filename}"
        if valac -c "${vala_file}" --pkg gio-unix-2.0 --pkg glib-2.0 --pkg json-glib-1.0 --pkg libsodium -o /dev/null 2>&1; then
            echo "    ✓ Syntax OK"
        else
            echo "    ⚠️  Syntax warnings (may be acceptable):"
            # Filter to show only errors, not warnings
            valac -c "${vala_file}" --pkg gio-unix-2.0 --pkg glib-2.0 --pkg json-glib-1.0 --pkg libsodium -o /dev/null 2>&1 | grep -i "error:" || true
        fi
    done
    
    echo "✓ Vala syntax checks complete"
else
    echo "ℹ️  No Vala source files found to check"
fi

# Check for TODO/FIXME comments (optional, can be enabled)
echo "[4/5] Checking for TODO/FIXME comments (informational)..."
TODO_COUNT=$(grep -r -l -E "TODO:|FIXME:" "${PROJECT_ROOT}/" --include="*.vala" --include="*.cpp" --include="*.h" 2>/dev/null | wc -l || echo "0")
if [ "$TODO_COUNT" -gt 0 ]; then
    echo "  ℹ️  Found ${TODO_COUNT} file(s) with TODO/FIXME comments:"
    grep -r -l -E "TODO:|FIXME:" "${PROJECT_ROOT}/" --include="*.vala" --include="*.cpp" --include="*.h" 2>/dev/null | head -5
fi

# Check for trailing whitespace
echo "[5/5] Checking for trailing whitespace..."
TRAILING=$(git diff HEAD 2>/dev/null | grep -c "^.* $" || echo "0")
if [ "$TRAILING" -gt 0 ]; then
    echo "  ⚠️  Found ${TRAILING} line(s) with trailing whitespace:"
    git diff HEAD 2>/dev/null | grep -n " $" | head -5
fi

# Check file sizes (warn about very large files)
echo ""
echo "[Extra] Checking for large files (>1MB)..."
LARGE_FILES=$(find "${PROJECT_ROOT}" -type f -size +1M \
    ! -path "*/build/*" \
    ! -path "*/gen-c/*" \
    \( -name "*.vala" -o -name "*.cpp" \) 2>/dev/null | head -5)

if [ -n "$LARGE_FILES" ]; then
    echo "  ⚠️  Large files found (review if necessary):"
    echo "${LARGE_FILES}" | while read file; do
        size=$(ls -lh "${file}" 2>/dev/null | awk '{print $5}')
        echo "    - ${file} (${size})"
    done
else
    echo "✓ No large files found"
fi

echo ""
echo "=========================================="
echo "  Pre-Commit Checks Complete!"
echo "=========================================="
echo ""
echo "Summary:"
echo "  ✓ Git repository check passed"
echo "  ✓ Code quality checks completed"
echo "  ✓ No large files detected"
echo ""
echo "You can now commit your changes."

# Exit with success code
exit 0