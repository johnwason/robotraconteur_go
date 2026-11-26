#!/usr/bin/env bash
# Builds the native part of the Robot Raconteur Go bindings and installs it
# into PREFIX (see "Building" in README.md):
#
#   scripts/build_native.sh PREFIX
#
#   PREFIX/lib/libRobotRaconteurCore.a          core, static
#   PREFIX/lib/libRobotRaconteurGoNative.a      SWIG wrapper, static
#   PREFIX/lib/pkgconfig/robotraconteur-go.pc   link line for cgo
#   PREFIX/bin/RobotRaconteurGenGo              robdef -> Go generator
#   PREFIX/include/...                          core headers
#
# Then: export PKG_CONFIG_PATH=PREFIX/lib/pkgconfig and use go build as usual.
#
# Environment (all optional):
#   RR_SRC            Robot Raconteur core source checkout to build. If unset,
#                     RR_GIT_URL is cloned at RR_GIT_REF into BUILD_DIR/robotraconteur.
#   RR_GIT_URL        default https://github.com/robotraconteur/robotraconteur.git
#   RR_GIT_REF        default v1.3.0 (a tag, branch or commit)
#   BUILD_DIR         build directory, default ./build-native
#   CORE_BUILD_DIR    build directory of the core, default BUILD_DIR/core
#   PREFIX_PATH       extra dependency prefixes (;-separated), e.g. where Boost is
#   BUILD_TYPE        CMake build type, default Release
#   JOBS              parallel jobs, default: number of CPUs
#   CMAKE_ARGS        extra arguments for both CMake projects (e.g. a toolchain file)
#   CORE_CMAKE_ARGS   extra arguments for the core only (e.g. -DBUILD_TESTING=ON)
#   CORE_TARGETS      core targets to build, default: all of the configured core
#   SKIP_CORE=1       reuse a core already built and installed in PREFIX
#
# Needs CMake, a C++ compiler, Boost (date_time filesystem regex chrono atomic
# thread random program_options) and, on Linux, OpenSSL, D-Bus, libusb and
# BlueZ headers (as for the core itself). SWIG and Python are not needed.
set -euo pipefail

if [ $# -ne 1 ]; then
  sed -n '2,12p' "$0" >&2
  exit 2
fi
mkdir -p "$1"
PREFIX=$(cd "$1" && pwd)
GO_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
BUILD_DIR=${BUILD_DIR:-$PWD/build-native}
mkdir -p "$BUILD_DIR"
BUILD_DIR=$(cd "$BUILD_DIR" && pwd)
CORE_BUILD_DIR=${CORE_BUILD_DIR:-$BUILD_DIR/core}
BUILD_TYPE=${BUILD_TYPE:-Release}
PREFIX_PATH=${PREFIX_PATH:-}
JOBS=${JOBS:-$(getconf _NPROCESSORS_ONLN 2>/dev/null || echo 2)}
RR_GIT_URL=${RR_GIT_URL:-https://github.com/robotraconteur/robotraconteur.git}
RR_GIT_REF=${RR_GIT_REF:-v1.3.0}
read -r -a EXTRA <<< "${CMAKE_ARGS:-}"
read -r -a CORE_EXTRA <<< "${CORE_CMAKE_ARGS:-}"
read -r -a TARGETS <<< "${CORE_TARGETS:-}"

GEN=()
if command -v ninja > /dev/null; then GEN=(-G Ninja); fi
case "$(uname -s)" in
  MINGW*|MSYS*|CYGWIN*) EXTRA+=(-DBoost_USE_STATIC_LIBS=ON) ;; # no Boost DLLs needed by Go programs
esac

if [ -z "${RR_SRC:-}" ]; then
  RR_SRC=$BUILD_DIR/robotraconteur
  if [ ! -d "$RR_SRC/.git" ]; then
    echo "build_native: cloning $RR_GIT_URL ($RR_GIT_REF)"
    git clone --quiet "$RR_GIT_URL" "$RR_SRC"
  fi
  git -C "$RR_SRC" fetch --quiet origin "$RR_GIT_REF" 2>/dev/null || true
  git -C "$RR_SRC" checkout --quiet "$RR_GIT_REF" 2>/dev/null || git -C "$RR_SRC" checkout --quiet FETCH_HEAD
fi
RR_SRC=$(cd "$RR_SRC" && pwd)
echo "build_native: core $RR_SRC ($(git -C "$RR_SRC" describe --tags --always 2>/dev/null || echo unknown)) -> $PREFIX"

if [ "${SKIP_CORE:-0}" != 1 ]; then
  cmake -S "$RR_SRC" -B "$CORE_BUILD_DIR" "${GEN[@]}" \
    -DCMAKE_BUILD_TYPE="$BUILD_TYPE" -DCMAKE_INSTALL_PREFIX="$PREFIX" ${PREFIX_PATH:+"-DCMAKE_PREFIX_PATH=$PREFIX_PATH"} \
    -DBUILD_SHARED_LIBS=OFF -DCMAKE_POSITION_INDEPENDENT_CODE=ON \
    -DBUILD_GEN=OFF -DBUILD_TESTING=OFF -DBUILD_DOCUMENTATION=OFF \
    "${EXTRA[@]}" "${CORE_EXTRA[@]}"
  if [ ${#TARGETS[@]} -gt 0 ]; then
    cmake --build "$CORE_BUILD_DIR" -j "$JOBS" --target "${TARGETS[@]}"
  else
    cmake --build "$CORE_BUILD_DIR" -j "$JOBS"
  fi
  # Unspecified: the library, headers, CMake config and RobotRaconteurGen, not test programs
  cmake --install "$CORE_BUILD_DIR" --component Unspecified > /dev/null
fi

cmake -S "$GO_DIR" -B "$BUILD_DIR/go" "${GEN[@]}" \
  -DCMAKE_BUILD_TYPE="$BUILD_TYPE" -DCMAKE_INSTALL_PREFIX="$PREFIX" "-DCMAKE_PREFIX_PATH=$PREFIX${PREFIX_PATH:+;$PREFIX_PATH}" \
  -DRR_SOURCE_DIR="$RR_SRC" "${EXTRA[@]}"
cmake --build "$BUILD_DIR/go" -j "$JOBS"
cmake --install "$BUILD_DIR/go"

cat <<EOF

build_native: installed in $PREFIX. To use it:
  export PKG_CONFIG_PATH=$PREFIX/lib/pkgconfig\${PKG_CONFIG_PATH:+:\$PKG_CONFIG_PATH}
  export PATH=$PREFIX/bin:\$PATH        # RobotRaconteurGenGo, for go generate
EOF
