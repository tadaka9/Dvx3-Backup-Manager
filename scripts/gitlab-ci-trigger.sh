#!/bin/bash
#
# trigger-gitlab-ci.sh — Trigger GitLab CI via API
# 
# Prerequisites:
#   1. Create a Personal Access Token (PAT) on GitLab:
#      https://gitlab.com/profile/personal_access_tokens
#      - Scope needed: "api" or "read_registry"
#      - Project access: "Maintainer" permission required to trigger pipelines
#
#   2. Set the token in environment or pass as argument:
#      export GITLAB_API_TOKEN=glpat-xxxxxxxxxxxxxxxxxxxx
#
# Usage:
#   ./scripts/gitlab-ci-trigger.sh [GITLAB_URL] [BRANCH]
#
# Example:
#   ./scripts/gitlab-ci-trigger.sh https://gitlab.com/dvx3/dvx3-backup-manager.git main

set -euo pipefail

GITLAB_URL="${1:-https://gitlab.com}"
BRANCH="${2:-main}"
API_TOKEN="${GITLAB_API_TOKEN:?Error: GITLAB_API_TOKEN not set. Run: export GITLAB_API_TOKEN=glpat-...}"
PROJECT_NAME="dvx3-backup-manager"

# Determine project path (handle username/project format)
if [ -n "${GITLAB_PROJECT_PATH:-}" ]; then
    PROJECT_PATH="$GITLAB_PROJECT_PATH"
else
    echo "🔍 Detecting project..."
    
    # Try to find the repo by name
    for user in dvx3 tadaka9 root gitlab-org; do
        if curl -s "https://gitlab.com/api/v4/projects/${user}/${PROJECT_NAME}?per_page=1" \
            -H "PRIVATE-TOKEN: ${API_TOKEN}" 2>/dev/null | grep -q "\"name\""; then
            PROJECT_PATH="${user}/${PROJECT_NAME}"
            echo "✓ Found project: gitlab.com/${user}/${PROJECT_NAME}"
            break
        fi
    done
    
    if [ -z "$PROJECT_PATH" ]; then
        echo "⚠️  Could not auto-detect project. Set GITLAB_PROJECT_PATH explicitly."
        echo "   Example: GITLAB_PROJECT_PATH=my-group/my-project ./scripts/gitlab-ci-trigger.sh"
        exit 1
    fi
fi

echo ""
echo "=========================================="
echo "  GitLab CI Trigger Script"
echo "=========================================="
echo "  URL:     $GITLAB_URL/$PROJECT_PATH"
echo "  Branch:  $BRANCH"
echo "  Token:   [HIDDEN] (length=${#API_TOKEN})"
echo ""

# Build the trigger payload
PAYLOAD='{"ref":"'$BRANCH'"}'

# Trigger pipeline via GitLab API
RESPONSE=$(curl -s \
    -X POST \
    --header "PRIVATE-TOKEN: ${API_TOKEN}" \
    --data "${PAYLOAD}" \
    "${GITLAB_URL}/api/v4/projects/${PROJECT_PATH}/pipeline" 2>&1)

echo "$RESPONSE" | python3 -c "
import sys, json
try:
    data = json.load(sys.stdin)
    if 'id' in data:
        print(f\"🚀 Pipeline triggered! ID: {data['id']}\")
        print(f\"   URL: https://gitlab.com{sys.argv[1].split('/')[-2]}/{sys.argv[1].split('/')[-1]}-/pipelines/{data['id']}\")
    elif 'message' in data:
        print(f\"❌ Error: {data['message']}\")
        sys.exit(1)
except json.JSONDecodeError as e:
    print(f\"⚠️  Could not parse response: {e}\")
    print(f\"   Raw response: {sys.stdin.read()}\")
"

echo ""
echo "✅ Trigger complete. Check the pipeline URL above for status."
