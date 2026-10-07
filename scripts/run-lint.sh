#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"
command -v shellcheck >/dev/null
while IFS= read -r file; do
  if [[ -f "$file" ]]; then shellcheck "$file"; fi
done < <(git ls-files -co --exclude-standard '*.sh')
if command -v actionlint >/dev/null 2>&1; then actionlint .github/workflows/ci.yml; fi
if command -v yamllint >/dev/null 2>&1; then yamllint -d relaxed .github/workflows/ci.yml; fi
