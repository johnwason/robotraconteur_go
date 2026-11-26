#!/usr/bin/env bash
# Regenerates the committed SWIG and header-derived sources (maintainers only;
# users build from the committed files and need neither SWIG nor Python).
# Run after changing swig/*.i, swig/postprocess_go.py or the core version:
#   scripts/podman.sh shell scripts/regen_swig.sh      (RR_SRC_DIR selects the core checkout)
#
# Writes:
#   robotraconteur/internal/swig/robotraconteurswig.go, upcasts_gen.go   Go side (all platforms)
#   native/gen/lp64/RobotRaconteurGo_wrap.cxx, .h    C++ side, int64_t is long (Linux, macOS)
#   native/gen/llp64/RobotRaconteurGo_wrap.cxx, .h   C++ side, int64_t is long long (Windows)
#   native/gen/rrgo_upcasts.cxx
#   robotraconteur/errors_gen.go, constants_gen.go                       from the core headers
# CI runs this and fails if the result differs from what is committed.
set -euo pipefail
GO_DIR=${GO_DIR:-/work/robotraconteur_go}
RR_SRC=${RR_SRC:-/work/robotraconteur}
cd "$GO_DIR"
T=$(mktemp -d)
trap 'rm -rf "$T"' EXIT
rm -rf native/gen && mkdir -p native/gen/lp64 native/gen/llp64

for model in lp64 llp64; do
  mkdir -p "$T/$model"
  wordsize=""
  [ "$model" = lp64 ] && wordsize=-DSWIGWORDSIZE64
  swig -go -cgo -c++ -intgosize 64 $wordsize -Iswig -I"$RR_SRC/SWIG" -I"$RR_SRC/RobotRaconteurCore/include" \
    -outdir "$T/$model" -o "$T/$model/RobotRaconteurGo_wrap.cxx" -xmlout "$T/$model/RobotRaconteurGo.xml" \
    swig/RobotRaconteurGo.i > "$T/$model/swig.log" 2>&1 || { cat "$T/$model/swig.log"; exit 1; }
  python3 swig/postprocess_go.py "$T/$model/robotraconteurswig.go" "$T/$model/RobotRaconteurGo.xml" \
    "$T/$model/upcasts_gen.go" "$T/$model/rrgo_upcasts.cxx" > /dev/null
  cp "$T/$model/RobotRaconteurGo_wrap.cxx" "$T/$model/RobotRaconteurGo_wrap.h" "native/gen/$model/"
done

# The Go side does not depend on the data model; check, then commit one copy.
for f in robotraconteurswig.go upcasts_gen.go rrgo_upcasts.cxx; do
  cmp -s "$T/lp64/$f" "$T/llp64/$f" || { echo "regen_swig: $f differs between lp64 and llp64" >&2; exit 1; }
done
cp "$T/lp64/robotraconteurswig.go" "$T/lp64/upcasts_gen.go" robotraconteur/internal/swig/
cp "$T/lp64/rrgo_upcasts.cxx" native/gen/

python3 cmake/gen_go_errors.py "$RR_SRC/RobotRaconteurCore/include/RobotRaconteur" robotraconteur/errors_gen.go
echo "regen_swig: sources regenerated from $(git -C "$RR_SRC" describe --tags --always 2>/dev/null || echo "$RR_SRC")"
