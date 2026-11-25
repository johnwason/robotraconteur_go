// Package gennames checks Go generator output for names and constants that
// need special handling (test/robdef/experimental.gen_test_go_names.robdef).
// That the package compiles is most of the test.
package gennames

import (
	"math"
	"testing"

	names "github.com/robotraconteur/robotraconteur_go/test/gen/experimental__gen_test_go_names"
)

func TestWrappedUnsignedConstants(t *testing.T) {
	if names.U32_neg != math.MaxUint32 {
		t.Errorf("u32_neg = %d", names.U32_neg)
	}
	if names.U16_neg != math.MaxUint16-1 {
		t.Errorf("u16_neg = %d", names.U16_neg)
	}
	want := []uint64{0, math.MaxUint64, 5}
	if len(names.U64_neg_array) != len(want) {
		t.Fatalf("u64_neg_array = %v", names.U64_neg_array)
	}
	for i, v := range want {
		if names.U64_neg_array[i] != v {
			t.Errorf("u64_neg_array[%d] = %d, want %d", i, names.U64_neg_array[i], v)
		}
	}
	if len(names.I32_array) != 2 || names.I32_array[0] != -1 || names.I32_array[1] != 16 {
		t.Errorf("i32_array = %v", names.I32_array)
	}
}
