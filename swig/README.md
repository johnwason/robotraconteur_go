# SWIG interface for the Go bindings

SWIG generates the internal package `robotraconteur/internal/swig` and the
C++ wrapper compiled into `libRobotRaconteurGoNative.a` (see the top-level
`CMakeLists.txt`). The entry point is `RobotRaconteurGo.i`. It includes the
shared interface files from the core checkout (`robotraconteur/SWIG/*.i`, used
unmodified, as the C#, Java and Python bindings do) and adds the Go-specific
files in this directory:

- **`go_shared_ptr.i`**: SWIG's Go module has no `boost_shared_ptr.i`. This
  file provides `%shared_ptr` and `%rr_intrusive_ptr`.
- **`TimerGo.i`, `TimeSpecGo.i`**: ports of the .NET `TimerNET.i` and
  `TimeSpecNET.i` without the C# modifiers. `TimerGo.i` also exposes
  `Timer::Clear`, which releases a timer's handler.
- **`GoTypemaps.i`, `GoExceptionTypemaps.i`, `rrgo_support.h`**: typemaps,
  and the C++ exception to Go `error` plumbing (a thread-local pending error).
- **`RRGoTestSupport.i`**: error-path test hooks.
- **`postprocess_go.py`**: rewrites the generated Go file (smart pointer
  aliases, upcasts; writes `upcasts_gen.go` and `rrgo_upcasts.cxx`).

`cmake/gen_go_errors.py` generates the Go error types and constants from the
core headers, and `cmake/gen_cgo_flags.py` writes the cgo link flags.
