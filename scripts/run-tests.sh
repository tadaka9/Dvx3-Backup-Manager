#!/usr/bin/env bash
set -euo pipefail

# Minimal test harness: prefer running ctest if available, otherwise fallback to running known test binaries.

TESTS=(
  tests/test_simple
  tests/test_exclusion
)

# If tests built via CMake, run ctest in the tests/build directory
if command -v ctest >/dev/null 2>&1 && [ -d tests/build ]; then
  echo "Running ctest in tests/build..."
  pushd tests/build || true
  ctest --output-on-failure || exit 1
  popd || true
  exit 0
fi

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
