#!/usr/bin/env bash
HERE="$(dirname "$(readlink -f "$0")")"
if [ -x "$HERE/linux/run-gui.sh" ]; then
  exec "$HERE/linux/run-gui.sh" "$@"
else
  echo "No Linux package found in $HERE/linux" >&2
  exit 1
fi
