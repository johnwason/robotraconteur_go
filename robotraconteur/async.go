package robotraconteur

import (
	"math"
	"time"

	swig "github.com/robotraconteur/robotraconteur_go/robotraconteur/internal/swig"
)

// Completion directors for native asynchronous operations. Their handlers
// run on Robot Raconteur thread pool threads and must not block; the only
// handlers used are await completions (a non-blocking channel send).

// TimeoutInfinite disables a timeout.
const TimeoutInfinite time.Duration = -1

// TimeoutDefault uses the node's default timeout.
const TimeoutDefault time.Duration = -2

// timeoutMs converts a timeout, period or lifespan to native milliseconds:
// TimeoutDefault -> -2, other negative values -> -1 (infinite), and positive
// values rounded up, so that a sub-millisecond duration does not become 0.
func timeoutMs(t time.Duration) int32 {
	switch {
	case t == TimeoutDefault:
		return -2
	case t < 0:
		return -1
	}
	return int32(durationMsCeil(t, math.MaxInt32))
}

// durationMsCeil returns t (>= 0) in milliseconds, rounded up and clamped to max.
func durationMsCeil(t time.Duration, max int64) int64 {
	ms := t / time.Millisecond
	if t%time.Millisecond != 0 {
		ms++
	}
	if int64(ms) > max {
		return max
	}
	return int64(ms)
}

// settingMsU32 converts a duration for a native uint32 millisecond setting.
// The settings have no infinite value: negative durations (TimeoutInfinite)
// give the largest one, about 49 days.
func settingMsU32(t time.Duration) uint32 {
	if t < 0 {
		return math.MaxUint32
	}
	return uint32(durationMsCeil(t, math.MaxUint32))
}

// ---- AsyncRequestDirector: returns a message element ----

type asyncRequest struct {
	handler func(*Element, error)
}

func (d *asyncRequest) Handler(ret swig.MessageElement, info swig.HandlerErrorInfo) {
	defer recoverDirector()
	// Handles passed to directors are owned by Go.
	if ret != nil && ret.Swigcptr() != 0 {
		defer swig.DeleteMessageElement(ret)
	}
	err := errorFromInfo(info)
	var e *Element
	if err == nil && ret != nil && ret.Swigcptr() != 0 {
		e, err = fromNative(ret)
	}
	d.handler(e, err)
}

// newAsyncRequest creates a director and heap id for an async request.
func newAsyncRequest(handler func(*Element, error)) (swig.AsyncRequestDirector, int32) {
	impl := &asyncRequest{handler: handler}
	d := swig.NewDirectorAsyncRequestDirector(impl)
	id := heapAdd(impl, func() { swig.DeleteDirectorAsyncRequestDirector(d) })
	return d, id
}

// ---- AsyncVoidReturnDirector ----

type asyncVoid struct{ handler func(error) }

func (d *asyncVoid) Handler(info swig.HandlerErrorInfo) {
	defer recoverDirector()
	err := errorFromInfo(info)
	d.handler(err)
}

func newAsyncVoid(handler func(error)) (swig.AsyncVoidReturnDirector, int32) {
	impl := &asyncVoid{handler: handler}
	d := swig.NewDirectorAsyncVoidReturnDirector(impl)
	id := heapAdd(impl, func() { swig.DeleteDirectorAsyncVoidReturnDirector(d) })
	return d, id
}

// ---- AsyncVoidNoErrReturnDirector ----

type asyncVoidNoErr struct{ handler func() }

func (d *asyncVoidNoErr) Handler() {
	defer recoverDirector()
	d.handler()
}

func newAsyncVoidNoErr(handler func()) (swig.AsyncVoidNoErrReturnDirector, int32) {
	impl := &asyncVoidNoErr{handler: handler}
	d := swig.NewDirectorAsyncVoidNoErrReturnDirector(impl)
	id := heapAdd(impl, func() { swig.DeleteDirectorAsyncVoidNoErrReturnDirector(d) })
	return d, id
}

// ---- AsyncStringReturnDirector ----

type asyncString struct{ handler func(string, error) }

func (d *asyncString) Handler(ret string, info swig.HandlerErrorInfo) {
	defer recoverDirector()
	err := errorFromInfo(info)
	d.handler(ret, err)
}

func newAsyncString(handler func(string, error)) (swig.AsyncStringReturnDirector, int32) {
	impl := &asyncString{handler: handler}
	d := swig.NewDirectorAsyncStringReturnDirector(impl)
	id := heapAdd(impl, func() { swig.DeleteDirectorAsyncStringReturnDirector(d) })
	return d, id
}

// ---- AsyncStubReturnDirector ----

type asyncStub struct {
	node    *Node
	handler func(any, error)
}

func (d *asyncStub) Handler(stub swig.WrappedServiceStub, info swig.HandlerErrorInfo) {
	defer recoverDirector()
	err := errorFromInfo(info)
	var obj any
	if err == nil {
		obj, err = d.node.stubFromNative(stub)
	} else if stub != nil && stub.Swigcptr() != 0 {
		swig.DeleteWrappedServiceStub(stub)
	}
	d.handler(obj, err)
}

func newAsyncStub(node *Node, handler func(any, error)) (swig.AsyncStubReturnDirector, int32) {
	impl := &asyncStub{node: node, handler: handler}
	d := swig.NewDirectorAsyncStubReturnDirector(impl)
	id := heapAdd(impl, func() { swig.DeleteDirectorAsyncStubReturnDirector(d) })
	return d, id
}
