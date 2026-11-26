//go:build !rrgo_customenv

package robotraconteurswig

// The native part of the bindings (the static libRobotRaconteurGoNative.a,
// RobotRaconteurCore and their dependencies) is found with pkg-config:
// robotraconteur-go.pc, installed by scripts/build_native.sh. Point
// PKG_CONFIG_PATH at <prefix>/lib/pkgconfig. See "Building" in README.md.
//
// Build with -tags rrgo_customenv to leave out this directive and pass the
// flags in CGO_CFLAGS and CGO_LDFLAGS instead.

/*
#cgo pkg-config: robotraconteur-go
*/
import "C"
