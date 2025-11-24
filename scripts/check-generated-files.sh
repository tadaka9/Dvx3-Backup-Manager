#!/usr/bin/env bash
# scripts/check-generated-files.sh
# Exit with non-zero if generated files are present in git index (staged or tracked)

set -euo pipefail

# Patterns to error on (always)
BLOCK_PATTERNS=("\\.moc\\.cpp$" "\\.rcc\\.cpp$")
# gen-c check: Not allowed to be tracked. Untracked gen-c/ is permitted for local builds.
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
  # Check if gen-c/ is tracked in the git index. We allow the directory to exist
  # locally when untracked (e.g. after valac generation), but we do not allow
  # the generated files to be tracked by git in the repository.
  gen_c_tracked=$(git ls-files -- "$GEN_C_PATH" | wc -l || true)
  if [ "$gen_c_tracked" -gt 0 ]; then
    echo "ERROR: Found tracked 'gen-c/' directory. This contains generated C code."
    echo "Action: Remove 'gen-c/' from the repository index (not the working copy) and add it to .gitignore."
    echo "  git rm -r --cached gen-c && echo 'gen-c/' >> .gitignore && git add .gitignore && git commit -m \"chore: untrack generated 'gen-c/' files\""
    echo "Note: If the generated C files are required during a local build, valac will regenerate them when needed."
    ls -la "$GEN_C_PATH" || true
    errors=1
  else
    echo "Info: gen-c directory present but not tracked in git index (allowed)."
  fi
fi

exit $errors
