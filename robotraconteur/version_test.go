package robotraconteur

import (
	"os"
	"regexp"
	"testing"
)

// Version must match the CMake project version (CMakeLists.txt).
func TestVersionMatchesCMake(t *testing.T) {
	b, err := os.ReadFile("../CMakeLists.txt")
	if err != nil {
		t.Skip("CMakeLists.txt not found:", err)
	}
	m := regexp.MustCompile(`project\(RobotRaconteurGo VERSION ([0-9.]+)`).FindSubmatch(b)
	if m == nil {
		t.Fatal("no project version in CMakeLists.txt")
	}
	if string(m[1]) != Version {
		t.Errorf("Version %q, CMakeLists.txt %q", Version, m[1])
	}
}
