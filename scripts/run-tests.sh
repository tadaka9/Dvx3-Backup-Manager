#!/usr/bin/env bash
set -euo pipefail

# Minimal test harness: prefer running ctest if available, otherwise fallback to running known test binaries.

TESTS=(
  tests/test_simple
  tests/test_exclusion
)

# If tests built via CMake, build using Ninja (fast) and run ctest in the tests/build directory
if command -v ctest >/dev/null 2>&1 && command -v ninja >/dev/null 2>&1; then
  if [ ! -d tests/build ]; then
    echo "Configuring tests build dir with Ninja generator"
    cmake -G Ninja -S tests -B tests/build -DCMAKE_BUILD_TYPE=Release
  fi
  if [ -d tests/build ]; then
  echo "Running ctest in tests/build..."
  pushd tests/build || true
    cmake --build . --parallel || true
    ctest --output-on-failure || exit 1
  popd || true
  exit 0
  fi
fi

EXITCODE=0
for t in "${TESTS[@]}"; do
  if [ -x "./$t" ]; then
    echo "Running ./$t"
    ./$t || { echo "Test $t failed"; EXITCODE=1; }
  else
    echo "Test binary ./$t not found, skipping."
    EXITCODE=1
  fi
done

exit $EXITCODE
