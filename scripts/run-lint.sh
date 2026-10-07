#!/usr/bin/env bash
set -eu -o pipefail

# scripts/run-lint.sh
# Runs the same linters that were previously run in CI (`yamllint`, `actionlint`, `shellcheck`) so contributors can validate locally.
# Notes:
# - Requires `yamllint`, `actionlint`, and `shellcheck` installed on your platform.
# - On Ubuntu you can install them with: `sudo apt-get install -y yamllint shellcheck` and `go install github.com/rhysd/actionlint/cmd/actionlint@latest`.

echo "Running yamllint for .github/workflows"
if command -v yamllint >/dev/null 2>&1; then
  yamllint -c /dev/null .github/workflows || true
else
  echo "Warning: yamllint not found, skipping"
fi

echo "Running actionlint on workflows"
if command -v actionlint >/dev/null 2>&1; then
  actionlint .github/workflows || true
else
  echo "Warning: actionlint not found, skipping (install with 'go install github.com/rhysd/actionlint/cmd/actionlint@latest')"
fi

echo "Shellchecking .sh files listed in git"
files=$(git ls-files '*.sh' || true)
if [ -n "$files" ] && command -v shellcheck >/dev/null 2>&1; then
  for f in $files; do
    echo "Shellcheck: $f"
    shellcheck -x "$f" || true
  done
else
  echo "Warning: shellcheck not found, skipping"
fi

echo "Done."
