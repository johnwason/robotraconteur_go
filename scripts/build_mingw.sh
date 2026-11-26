#!/usr/bin/env bash
# Cross-build for Windows x86_64 with MinGW-w64, inside the mingw image:
#   scripts/podman.sh mingw-build [all|go]     go: reuse the core in build-mingw/install
# The same steps as a user build (scripts/build_native.sh) with the MinGW-w64
# toolchain, into build-mingw/install. RobotRaconteurGenGo.exe is also built
# but cannot run here; scripts/cross_test_build.sh generates code with the
# Linux generator instead.
set -euo pipefail
GO_DIR=/work/robotraconteur_go
BUILD=${BUILD:-$GO_DIR/build-mingw}
TOOLCHAIN=${TOOLCHAIN:-/opt/mingw64/toolchain.cmake}
export JOBS=${JOBS:-2}
export BUILD_TYPE=${BUILD_TYPE:-Release}
export RR_SRC=${RR_SRC:-/work/robotraconteur}
export BUILD_DIR=$BUILD CORE_BUILD_DIR=$BUILD/rr
export PREFIX_PATH=/opt/mingw64     # Boost and GTest built for MinGW in the image
# -static: executables (generator, C++ test programs) need no MinGW runtime DLLs
export CMAKE_ARGS="-DCMAKE_TOOLCHAIN_FILE=$TOOLCHAIN -DCMAKE_C_COMPILER_LAUNCHER=ccache
  -DCMAKE_CXX_COMPILER_LAUNCHER=ccache -DCMAKE_EXE_LINKER_FLAGS=-static"
export CORE_TARGETS=RobotRaconteurCore

# RR_TESTING=ON also builds the core's C++ test programs used by test/interop
# and test/crosscheck. Their thunk code is generated with the Linux
# RobotRaconteurGen from "scripts/podman.sh build" (HOST_RRGEN).
HOST_RRGEN=${HOST_RRGEN:-$GO_DIR/build/install/bin/RobotRaconteurGen}
CPP_TESTS="robotraconteur_test_server robotraconteur_test_service robotraconteur_test_service2 robotraconteur_test_service3"
if [ "${RR_TESTING:-OFF}" = ON ]; then
  # PRE_TEST: gtest test discovery would run the .exe at build time
  export CORE_CMAKE_ARGS="-DBUILD_TESTING=ON -DRobotRaconteurGen_EXECUTABLE=$HOST_RRGEN
    -DCMAKE_GTEST_DISCOVER_TESTS_DISCOVERY_MODE=PRE_TEST"
fi
[ "${1:-all}" = go ] && export SKIP_CORE=1

mkdir -p "$BUILD"; [ -f "$BUILD/go.mod" ] || printf "module rrgo_build_ignore\n" > "$BUILD/go.mod"

"$GO_DIR/scripts/build_native.sh" "$BUILD/install"

if [ "${RR_TESTING:-OFF}" = ON ] && [ "${SKIP_CORE:-0}" != 1 ]; then
  # only the programs the Go tests run (not the GTest unit tests)
  cmake --build "$BUILD/rr" -j 1 --target $CPP_TESTS
  mkdir -p "$BUILD/tests/cpp"
  for t in $CPP_TESTS; do cp "$(find "$BUILD/rr/test" -name "$t.exe" -path "*bin*" | head -1)" "$BUILD/tests/cpp/"; done
fi
