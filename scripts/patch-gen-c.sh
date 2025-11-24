#!/usr/bin/env bash
set -euo pipefail

# Usage: patch-gen-c.sh <file>
if [ $# -ne 1 ]; then
  echo "Usage: $0 <file>"
  exit 1
fi
file="$1"
if [ ! -f "$file" ]; then
  echo "File not found: $file" >&2
  exit 1
fi

echo "Patching generated C: $file"
perl -0777 -pe 's/g_once_init_enter\s*\(\s*&([A-Za-z_][A-Za-z0-9_]*)\s*\)/g_once_init_enter ((volatile gpointer *) \&$1)/g; s/g_once_init_leave\s*\(\s*&([A-Za-z_][A-Za-z0-9_]*)\s*\)/g_once_init_leave ((volatile gpointer *) \&$1)/g' -i "$file" || true
echo "Patch complete"
