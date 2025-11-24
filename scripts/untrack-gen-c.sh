#!/usr/bin/env bash
set -euo pipefail

if [ ! -d gen-c ]; then
  echo "No gen-c/ directory found; nothing to untrack."
  exit 0
fi

echo "Untracking gen-c/ from git index and adding it to .gitignore"
git rm -r --cached gen-c || true
if ! grep -q "^gen-c/" .gitignore 2>/dev/null; then
  echo "gen-c/" >> .gitignore
  git add .gitignore
fi

echo "Commiting changes: 'Untrack gen-c generated files'"
git commit -m "chore: untrack generated 'gen-c/' files" || true

echo "Please push the changes to update the remote repository."

echo "Done."
