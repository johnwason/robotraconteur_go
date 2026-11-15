#!/usr/bin/env bash
# Cross-build for Windows x86_64 with MinGW-w64. Runs inside the mingw image:
#   scripts/podman.sh mingw-build [all|core|go]
# Stage 1: upstream RobotRaconteurCore (static) cross-built, installed to build-mingw/install.
# Stage 2: Go bindings native library (SWIG wrapper) cross-built; cgo_flags_windows.go generated.
# RobotRaconteurGenGo.exe is also built, but cannot run here; scripts/cross_test_build.sh
# generates code with the Linux generator instead.
set -euo pipefail
GO_DIR=/work/robotraconteur_go
RR_SRC=${RR_SRC:-/work/robotraconteur}
BUILD=${BUILD:-$GO_DIR/build-mingw}
JOBS=${JOBS:-2}
BUILD_TYPE=${BUILD_TYPE:-Release}
TOOLCHAIN=${TOOLCHAIN:-/opt/mingw64/toolchain.cmake}
RR_TESTING_ARG=""
if [ -n "${RR_TESTING:-}" ]; then RR_TESTING_ARG="-DBUILD_TESTING=$RR_TESTING"; fi

mkdir -p "$BUILD"; [ -f "$BUILD/go.mod" ] || printf "module rrgo_build_ignore\n" > "$BUILD/go.mod"

MODE=${1:-all}
TARGET=${2:-}

if [ "$MODE" != "go" ]; then
cmake -S "$RR_SRC" -B "$BUILD/rr" -G Ninja \
  -DCMAKE_TOOLCHAIN_FILE="$TOOLCHAIN" \
  -DCMAKE_BUILD_TYPE=$BUILD_TYPE \
  -DCMAKE_INSTALL_PREFIX="$BUILD/install" \
  -DCMAKE_PREFIX_PATH=/opt/mingw64 \
  -DCMAKE_C_COMPILER_LAUNCHER=ccache -DCMAKE_CXX_COMPILER_LAUNCHER=ccache \
  -DBUILD_GEN=OFF ${RR_TESTING_ARG:--DBUILD_TESTING=OFF} -DBUILD_DOCUMENTATION=OFF
cmake --build "$BUILD/rr" -j "$JOBS" ${TARGET:+--target "$TARGET"}
cmake --install "$BUILD/rr" >/dev/null
fi

if [ "$MODE" = "core" ]; then exit 0; fi

cmake -S "$GO_DIR" -B "$BUILD/go" -G Ninja \
  -DCMAKE_TOOLCHAIN_FILE="$TOOLCHAIN" \
  -DCMAKE_BUILD_TYPE=$BUILD_TYPE \
  -DCMAKE_PREFIX_PATH="$BUILD/install;/opt/mingw64" \
  -DRR_SOURCE_DIR="$RR_SRC" \
  -DCMAKE_C_COMPILER_LAUNCHER=ccache -DCMAKE_CXX_COMPILER_LAUNCHER=ccache
cmake --build "$BUILD/go" -j "$JOBS" ${TARGET:+--target "$TARGET"}
