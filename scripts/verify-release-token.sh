#!/usr/bin/env bash
set -euo pipefail

# verify-release-token.sh - verify a GitHub token's scopes and repo access
# Usage:
#   ./scripts/verify-release-token.sh --token <token> --repo owner/repo --verbose
# If no token is provided, will check environment variables RELEASE_PAT, GITHUB_TOKEN.

usage() {
  cat <<EOF
Usage: $0 [--token TOKEN] [--repo owner/repo] [--verbose] [--create-test]

--token TOKEN       Use provided token instead of reading RELEASE_PAT/GITHUB_TOKEN envs.
--repo owner/repo   Repository full name to check (default uses git remote origin to infer).
--verbose           Print extra details and curl output.
--create-test       (Optional) Attempt to create a test tag 'verify-token-test' (requires repo:create permission) and clean it up.
EOF
}

TOKEN=""
REPO=""
VERBOSE=0
CREATE_TEST=0

while [ $# -gt 0 ]; do
  case "$1" in
    --token) TOKEN="$2"; shift 2 ;;
    --repo) REPO="$2"; shift 2 ;;
    --verbose) VERBOSE=1; shift ;;
    --create-test) CREATE_TEST=1; shift ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Unknown arg: $1"; usage; exit 2 ;;
  esac
done

# Determine token from env fallback
if [ -z "$TOKEN" ]; then
  if [ -n "${RELEASE_PAT:-}" ]; then TOKEN="$RELEASE_PAT"; fi
  if [ -z "$TOKEN" ] && [ -n "${GITHUB_TOKEN:-}" ]; then TOKEN="$GITHUB_TOKEN"; fi
fi

if [ -z "$TOKEN" ]; then
  echo "Error: No token provided. Set RELEASE_PAT or GITHUB_TOKEN env, or use --token." >&2
  exit 2
fi

# Determine repo if not provided
if [ -z "$REPO" ]; then
  if git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    ORIG=$(git remote get-url origin 2>/dev/null || true)
    if [ -n "$ORIG" ]; then
      # convert ssh or https remote to owner/repo
      REPO=$(echo "$ORIG" | sed -E 's#.*[:/]([^/]+/[^/.]+)(\.git)?$#\1#')
    fi
  fi
fi

if [ -z "$REPO" ]; then
  echo "Repository not specified and could not be inferred. Use --repo owner/repo." >&2
  exit 2
fi

MASKED_TOKEN="${TOKEN:0:4}****${TOKEN: -4}"
echo "Verifying token for repo: $REPO (token masked: $MASKED_TOKEN)"

# Collect headers and body separately for better diagnostics
HEADERS=$(mktemp)
BODY=$(mktemp)
HTTP_RESPONSE=$(curl -sS -w "HTTPSTATUS:%{http_code}" -H "Authorization: token $TOKEN" "https://api.github.com/repos/$REPO" -o "$BODY" 2>/dev/null) || true
STATUS=$(echo "$HTTP_RESPONSE" | sed -e 's/.*HTTPSTATUS://')
curl -sSI -H "Authorization: token $TOKEN" "https://api.github.com/repos/$REPO" | tee "$HEADERS" >/dev/null || true
if [ -z "$STATUS" ]; then
  echo "Failed to reach GitHub API. Check token or network." >&2
  rm -f $HEADERS
  exit 2
fi

echo "HTTP status: $STATUS"
if [ "$STATUS" -ne 200 ]; then
  echo "Token cannot access repo metadata (status $STATUS). Check token or repo permissions." >&2
fi

# Print OAuth scopes
XSCOPES=$(grep -i -E "^X-OAuth-Scopes:" $HEADERS || true)
XACCEPTED=$(grep -i -E "^X-Accepted-OAuth-Scopes:" $HEADERS || true)
echo "$XSCOPES"
echo "$XACCEPTED"

if [ $VERBOSE -eq 1 ]; then
  echo "Full response headers (curl -I):" && cat "$HEADERS"
  echo "Full response body (curl):"
  if command -v jq >/dev/null 2>&1; then
    jq '.' "$BODY" || cat "$BODY"
  else
    cat "$BODY"
  fi
fi

# Check if repo privileges look sufficient
if echo "$XSCOPES" | grep -qi 'repo'; then
  echo "Token has 'repo' scope (full access to repo)."
elif echo "$XSCOPES" | grep -qi 'public_repo'; then
  echo "Token has 'public_repo' scope (no private repo write access)."
else
  echo "Token does NOT list 'repo' or 'public_repo' in scopes; it may lack release creation privileges." >&2
fi

if [ "$CREATE_TEST" -eq 1 ]; then
  echo "Trying to create test tag 'temprelease-verify-$(date +%s)'..."
  TEST_TAG="temprelease-verify-$(date +%s)"
  # Attempt to create the tag
  payload=$(printf '{"ref":"refs/tags/%s","sha":"%s"}' "$TEST_TAG" "$(git rev-parse HEAD)")
  # Try to POST and capture body and HTTP status
  HTTP_CREATE_RESPONSE=$(curl -sS -w "HTTPSTATUS:%{http_code}" -H "Authorization: token $TOKEN" -H "Content-Type: application/json" -X POST "https://api.github.com/repos/$REPO/git/refs" -d "$payload" -o /tmp/create.out) || true
  CR=$(echo "$HTTP_CREATE_RESPONSE" | sed -e 's/.*HTTPSTATUS://')
  echo "Create tag HTTP status: $CR"
  echo "Create response body (create test):"
  if command -v jq >/dev/null 2>&1; then
    jq '.' /tmp/create.out || cat /tmp/create.out
  else
    cat /tmp/create.out
  fi
  rm -f /tmp/create.out || true
  if [ "$CR" -eq 201 ]; then
    echo "Tag created: $TEST_TAG (now deleting)"
    # Delete created ref
    curl -s -X DELETE -H "Authorization: token $TOKEN" "https://api.github.com/repos/$REPO/git/refs/tags/$TEST_TAG" || true
    echo "Test tag created and removed successfully. Token can create tags (repo scope OK)."
  else
    echo "Failed to create test tag using provided token (HTTP $CR). Check the token's 'repo' scope." >&2
    exit 1
  fi
fi

rm -f $HEADERS
echo "Token verification complete."
exit 0
