package robotraconteur

import (
	"errors"
	"math"
	"testing"
	"time"
)

// Go counterparts of the Robot Raconteur 1.3 unpack and range hardening.

func TestMdCopyRangeDoesNotWrap(t *testing.T) {
	src := make([]int32, 16)
	for i := range src {
		src[i] = int32(i)
	}
	dst := make([]int32, 1)
	dims := []uint64{4, 4}
	// pos + count wraps to 0 in uint64: must be out of range, not element 3
	err := mdCopy(src, dims, []uint64{math.MaxUint64, 1}, dst, []uint64{1, 1}, []uint64{0, 0}, []uint64{1, 1})
	if !errors.Is(err, ErrOutOfRange) {
		t.Fatalf("wrapping position: got %v, want OutOfRange", err)
	}
	if dst[0] != 0 {
		t.Errorf("wrapping position copied element %d", dst[0])
	}
	if err := mdCopy(src, dims, []uint64{1, 2}, dst, []uint64{1, 1}, []uint64{0, 0}, []uint64{1, 1}); err != nil || dst[0] != 9 {
		t.Errorf("valid copy: %v %d", err, dst[0])
	}
}

func TestMdCopyArraySmallerThanDims(t *testing.T) {
	src := make([]int32, 1) // dims claim 1000x1000
	dst := make([]int32, 4)
	err := mdCopy(src, []uint64{1000, 1000}, []uint64{998, 998}, dst, []uint64{2, 2}, []uint64{0, 0}, []uint64{2, 2})
	if !errors.Is(err, ErrInvalidArgument) {
		t.Fatalf("got %v, want InvalidArgument", err)
	}
}

func TestDimsCountOverflow(t *testing.T) {
	if n := dimsCount([]uint32{65536, 65536, 65536, 65536}); n != -1 {
		t.Errorf("overflowing dims count = %d, want -1", n)
	}
	if n := dimsCount([]uint32{2, 3, 4}); n != 24 {
		t.Errorf("dims count = %d", n)
	}
	// dims that wrap to 0 must not match an empty array
	if _, err := unpackMultiDimArrayList[int32](&NestedList{Type: DataTypeMultiDimArray, Elements: []*Element{
		PackArray("dims", []uint32{65536, 65536, 65536, 65536}), PackArray("array", []int32{}),
	}}); err == nil {
		t.Error("multidimarray with overflowing dims accepted")
	}
}

func TestMdListCodecChecksDims(t *testing.T) {
	c := mdListCodec[testPod]{list: podListCodec[testPod, *testPod](), typeName: testPod{}.RRType(), mdType: DataTypePodMultiDimArray}
	l, err := c.pack([]uint32{1, 2}, []testPod{{}, {}})
	if err != nil {
		t.Fatal(err)
	}
	if _, _, err := c.unpack(l); err != nil {
		t.Fatalf("valid list: %v", err)
	}
	l.Elements[0] = PackArray("dims", []uint32{1000, 1000})
	if _, _, err := c.unpack(l); !errors.Is(err, ErrDataTypeError) {
		t.Errorf("dims/array mismatch: got %v, want DataTypeError", err)
	}
	l.Type = DataTypePodArray
	if _, _, err := c.unpack(l); !errors.Is(err, ErrDataTypeMismatch) {
		t.Errorf("wrong list type: got %v, want DataTypeMismatch", err)
	}
}

func TestDurationConversions(t *testing.T) {
	cases := []struct {
		d    time.Duration
		want int32
	}{
		{TimeoutDefault, -2}, {TimeoutInfinite, -1}, {0, 0},
		{500 * time.Microsecond, 1}, {time.Millisecond, 1}, {1500 * time.Microsecond, 2},
		{100 * 24 * time.Hour, math.MaxInt32},
	}
	for _, c := range cases {
		if got := timeoutMs(c.d); got != c.want {
			t.Errorf("timeoutMs(%v) = %d, want %d", c.d, got, c.want)
		}
	}
	if got := settingMsU32(TimeoutInfinite); got != math.MaxUint32 {
		t.Errorf("settingMsU32(TimeoutInfinite) = %d", got)
	}
	if got := settingMsU32(250 * time.Microsecond); got != 1 {
		t.Errorf("settingMsU32(250us) = %d", got)
	}
}
