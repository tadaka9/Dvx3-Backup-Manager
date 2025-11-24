#!/usr/bin/env bash
set -euo pipefail

# Minimal wrapper to run backup-manager-gui with the proper Qt env
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/env.sh"

# Allow an override of the platform; default to xcb on Linux
if [ -z "${QT_QPA_PLATFORM+x}" ]; then
    export QT_QPA_PLATFORM="xcb"
fi

exec "${SCRIPT_DIR}/backup-manager-gui" "$@"
