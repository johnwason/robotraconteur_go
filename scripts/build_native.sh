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
#   RR_GIT_REF        default d8a4b22855bda54d2670038b2dbdc10caea9ba4d (master: 1.3.0
#                     + #498 + #497 MinGW-w64; the commit CI tests). A tag, branch or commit.
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
RR_GIT_REF=${RR_GIT_REF:-d8a4b22855bda54d2670038b2dbdc10caea9ba4d}
# Split on any whitespace, including newlines (read -a alone stops at the first line)
read -r -d '' -a EXTRA <<< "${CMAKE_ARGS:-}" || true
read -r -d '' -a CORE_EXTRA <<< "${CORE_CMAKE_ARGS:-}" || true
read -r -d '' -a TARGETS <<< "${CORE_TARGETS:-}" || true

GEN=()
if command -v ninja > /dev/null; then GEN=(-G Ninja); fi
case "$(uname -s)" in
  MINGW*|MSYS*|CYGWIN*) EXTRA+=(-DBoost_USE_STATIC_LIBS=ON) ;; # no Boost DLLs needed by Go programs
esac

if [ -z "${RR_SRC:-}" ]; then
  RR_SRC=$BUILD_DIR/robotraconteur
  if [ ! -d "$RR_SRC/.git" ]; then
    echo "build_native: cloning $RR_GIT_URL"
    git clone --quiet --no-checkout -- "$RR_GIT_URL" "$RR_SRC"
  fi
  # Build exactly the requested ref: fetch it (a failure is an error, not a
  # fallback to an older checkout) and check out the fetched commit, detached,
  # so a stale local branch of the same name is never used.
  git -C "$RR_SRC" remote set-url origin "$RR_GIT_URL"
  if ! git -C "$RR_SRC" fetch --quiet --end-of-options origin "$RR_GIT_REF"; then
    echo "build_native: could not fetch $RR_GIT_REF from $RR_GIT_URL" >&2
    exit 1
  fi
  git -C "$RR_SRC" checkout --quiet --detach FETCH_HEAD
  echo "build_native: $RR_GIT_URL $RR_GIT_REF is $(git -C "$RR_SRC" rev-parse HEAD)"
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
