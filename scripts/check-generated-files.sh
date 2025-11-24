#!/usr/bin/env bash
# scripts/check-generated-files.sh
# Exit with non-zero if generated files are present in git index (staged or tracked)

set -euo pipefail

# Patterns to error on (always)
BLOCK_PATTERNS=("\\.moc\\.cpp$" "\\.rcc\\.cpp$")
# gen-c check: can be allowed by presence of a file .gen-c-allowed
GEN_C_PATH="gen-c"

# Get tracked files
tracked_files=$(git ls-files)

errors=0
for pat in "${BLOCK_PATTERNS[@]}"; do
  matches=$(echo "$tracked_files" | grep -E "$pat" || true)
  if [ -n "$matches" ]; then
    echo "ERROR: Found tracked files matching blocked pattern: $pat"
    echo "$matches"
    errors=1
  fi
done

if [ -d "$GEN_C_PATH" ]; then
  if [ ! -f ".gen-c-allowed" ]; then
    echo "ERROR: Found tracked 'gen-c/' directory. This contains generated C code."
    echo "To allow it temporarily, add a '.gen-c-allowed' file to the repo root with reason/justification, then remove it when gen-c is removed."
    ls -la "$GEN_C_PATH" || true
    errors=1
  else
    echo "Info: gen-c directory present and whitelisted via .gen-c-allowed"
  fi
fi

exit $errors
