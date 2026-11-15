#!/usr/bin/env bash
# Runs the Windows test binaries made by scripts/cross_test_build.sh, each in its
# package directory (as go test does). Runs on Windows (Git Bash), from the
# repository root:
#   scripts/run_windows_tests.sh [binary dir, default build-mingw/tests]
# Only loopback, intra and local transports are used by the tests.
set -uo pipefail
ROOT=$(pwd)
BIN=$(cd "${1:-build-mingw/tests}" && pwd)
failed=()
while read -r exe dir; do
  [ -n "$exe" ] || continue
  echo "=== $dir"
  if (cd "$ROOT/$dir" && "$BIN/$exe" -test.count=1 -test.timeout=600s); then
    echo "ok   $dir"
  else
    echo "FAIL $dir"
    failed+=("$dir")
  fi
done < "$BIN/tests.txt"
if [ ${#failed[@]} -ne 0 ]; then
  echo "failed packages: ${failed[*]}"
  exit 1
fi
