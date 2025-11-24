#!/usr/bin/env bash
set -euo pipefail

# Minimal test harness: run each test executable and report status

TESTS=(
  test-simple-backup
  test-exclusion
)

EXITCODE=0
for t in "${TESTS[@]}"; do
  if [ -x "./$t" ]; then
    echo "Running ./
$t"
    ./$t || { echo "Test $t failed"; EXITCODE=1; }
  else
    echo "Test binary ./$t not found, skipping."
    EXITCODE=1
  fi
done

exit $EXITCODE
