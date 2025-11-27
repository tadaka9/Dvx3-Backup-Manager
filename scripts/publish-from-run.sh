#!/usr/bin/env bash
set -euo pipefail

# publish-from-run.sh - trigger the CI 'publish-only' job to upload artifacts
# from a previous run to a GitHub release.
#
# Example:
#   ./scripts/publish-from-run.sh --run-id 123456 --tag v1.2.3 --ref clean-version --create-tag-if-missing
#
usage() {
  cat <<EOF
Usage: $0 --run-id RUN_ID --tag TAG [--ref REF] [--create-tag-if-missing] [--strict true|false] [--dry-run]

Options:
  --run-id RUN_ID                 The workflow run ID to download artifacts from
  --tag TAG                       The release tag to upload artifacts to (required)
  --ref REF                       Branch or ref to use when dispatching (default: clean-version)
  --create-tag-if-missing         If provided, pass create_tag_if_missing=true to the workflow
  --strict true|false             Set strict_artifact_checks value (default true)
  --dry-run                       Print command but don't execute
  -h, --help                      Show this help
EOF
}

RUN_ID=""
TAG=""
REF="clean-version"
CREATE_TAG_IF_MISSING="false"
STRICT_ARTIFACT_CHECKS="true"
DRY_RUN=0

while [ $# -gt 0 ]; do
  case "$1" in
    --run-id) RUN_ID="$2"; shift 2 ;;
    --tag) TAG="$2"; shift 2 ;;
    --ref) REF="$2"; shift 2 ;;
    --create-tag-if-missing) CREATE_TAG_IF_MISSING="true"; shift ;;
    --strict) STRICT_ARTIFACT_CHECKS="$2"; shift 2 ;;
    --dry-run) DRY_RUN=1; shift ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Unknown arg: $1"; usage; exit 2 ;;
  esac
done

if [ -z "$RUN_ID" ]; then
  echo "Error: --run-id is required" >&2; usage; exit 2
fi
if [ -z "$TAG" ]; then
  echo "Error: --tag is required" >&2; usage; exit 2
fi

WORKFLOW_NAME='Build, Package & Release'

CMD=(gh workflow run "$WORKFLOW_NAME" --ref "$REF" \
  --field publish_only=true \
  --field publish_artifacts_run_id="$RUN_ID" \
  --field release_tag="$TAG" \
  --field strict_artifact_checks="$STRICT_ARTIFACT_CHECKS")
if [ "$CREATE_TAG_IF_MISSING" = "true" ]; then
  CMD+=(--field create_tag_if_missing=true)
fi

echo "Constructed command: ${CMD[*]}"
if [ "$DRY_RUN" -eq 1 ]; then
  echo "Dry-run: not executing"; exit 0
fi

echo "Executing workflow dispatch..."
"${CMD[@]}"

echo "Workflow dispatch submitted. Use 'gh run list' to monitor." 
exit 0
