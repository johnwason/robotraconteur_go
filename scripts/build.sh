#!/usr/bin/env bash
# Development build (Linux), inside the dev container (scripts/podman.sh build).
# The same steps as a user build (scripts/build_native.sh), into build/install,
# plus RobotRaconteurGen and, with RR_TESTING=ON, the core's C++ test programs
# (used by test/interop and test/crosscheck; core build in build/rr).
#   scripts/build.sh [all|go]     go: reuse the core in build/install
set -euo pipefail
GO_DIR=/work/robotraconteur_go
BUILD=${BUILD:-$GO_DIR/build}
# 8 GB RAM hosts: RR core and the SWIG wrapper are memory hungry to compile
export JOBS=${JOBS:-2}
export BUILD_TYPE=${BUILD_TYPE:-RelWithDebInfo}
export RR_SRC=${RR_SRC:-/work/robotraconteur}
export BUILD_DIR=$BUILD CORE_BUILD_DIR=$BUILD/rr
export CMAKE_ARGS="-DCMAKE_C_COMPILER_LAUNCHER=ccache -DCMAKE_CXX_COMPILER_LAUNCHER=ccache"
# RobotRaconteurGen generates the thunks of the C++ test programs (here and in
# the Windows cross build)
export CORE_CMAKE_ARGS="-DBUILD_GEN=ON -DBUILD_TESTING=${RR_TESTING:-OFF}"
[ "${1:-all}" = go ] && export SKIP_CORE=1

# Keep build outputs out of the Go module (./... must not see them)
mkdir -p "$BUILD"; [ -f "$BUILD/go.mod" ] || printf "module rrgo_build_ignore\n" > "$BUILD/go.mod"

"$GO_DIR/scripts/build_native.sh" "$BUILD/install"
