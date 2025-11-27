#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<EOF
Usage: $0 <ref> [<ref>...]

Example: $0 v0.0.3-alpha112725
This script converts an https GitHub remote to an SSH remote and pushes the provided refs/tags.
EOF
}

if [ $# -lt 1 ]; then
  usage
  exit 2
fi

REMOTE_URL=$(git remote get-url origin 2>/dev/null || true)
if [ -z "$REMOTE_URL" ]; then
  echo "No origin remote configured; set a remote first" >&2
  exit 1
fi

if [[ "$REMOTE_URL" =~ github.com[:/](.+)/(.+)(\.git)?$ ]]; then
  OWNER=${BASH_REMATCH[1]}
  REPO=${BASH_REMATCH[2]}
  SSH_URL="git@github.com:${OWNER}/${REPO}.git"
else
  echo "Remote does not look like a GitHub repository: $REMOTE_URL" >&2
  exit 1
fi

echo "Switching origin remote to SSH: $SSH_URL"
git remote set-url origin "$SSH_URL"

echo "Pushing refs: $@"
git push origin "$@"

echo "Done. Restoring origin to HTTPS is optional if you prefer to revert (use 'git remote set-url origin <https-url>')"

exit 0
