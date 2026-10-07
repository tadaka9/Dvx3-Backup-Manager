#!/usr/bin/env bash
# scripts/setup-hooks.sh - convenience script for setting up Git hooks to use .githooks

set -euo pipefail

# Configure git to use the repository .githooks directory as our hooksPath
if git rev-parse --git-dir > /dev/null 2>&1; then
  echo "Setting core.hooksPath to .githooks in the current repository..."
  git config core.hooksPath .githooks
  echo "Done. Pre-commit hooks will be executed from .githooks when committing." 
else
  echo "Not a git repository. Run this from the repo root."
  exit 1
fi

# Ensure pre-commit hook is executable
if [ -f .githooks/pre-commit ]; then
  chmod +x .githooks/pre-commit
  echo ".githooks/pre-commit is now executable."
fi

# Print summary
echo "To revert this: git config --unset core.hooksPath"
