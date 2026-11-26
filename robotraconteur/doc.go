// Package robotraconteur is the Go runtime of Robot Raconteur, a
// communication framework for robotics and automation.
//
// The bindings wrap the Robot Raconteur C++ core through SWIG and provide a
// Go API on top of it. Service types are Go packages generated from .robdef
// service definitions by RobotRaconteurGenGo.
//
// # Building
//
// The native part (the core and the C++ side of the bindings) is built once
// with scripts/build_native.sh from the repository and found by cgo through
// pkg-config (robotraconteur-go.pc). See the Building section of the README:
// https://github.com/robotraconteur/robotraconteur_go#building
//
// # Client
//
// A client sets up the node, connects to a service by URL and calls its
// members through the generated interface:
//
//	setup, err := rr.ClientNodeSetup(rr.WithServiceTypes(reynard.Factory))
//	if err != nil {
//		return err
//	}
//	defer setup.Close()
//
//	obj, err := setup.Node.ConnectService(ctx, "rr+tcp://localhost:29200?service=reynard")
//	if err != nil {
//		return err
//	}
//	defer setup.Node.DisconnectService(obj)
//	r := obj.(reynard.Reynard)
//	err = r.Drive_robot(ctx, 0.5, -0.2, -1, false)
//
// Generated member names keep the robdef names, with the first letter
// capitalized (Drive_robot) and Get_/Set_ prefixes for properties and other
// members, as in the C++ bindings.
//
// # Concurrency
//
// Every network operation is a synchronous Go call that takes a
// context.Context. Internally it is the core's asynchronous operation, and the
// calling goroutine waits on a channel, so no OS thread is held while a
// request is in flight. Use goroutines for concurrency. Events, callbacks,
// wire and pipe notifications and timers run on core threads; start a
// goroutine from the handler for work that blocks.
//
// # Services
//
// A service object implements the generated interface (embedding the
// generated DefaultImpl for members it does not implement) and is registered
// with [Node.RegisterService]. Service members run on their own goroutines
// and receive a ctx describing the request ([CurrentEndpoint],
// [CurrentAuthenticatedUser]). [ServerNodeSetup] configures a node to accept
// connections.
//
// # Errors
//
// Failures are returned as error values. Robot Raconteur errors are *[Error]
// (match them with errors.Is against ErrXxx values, such as
// [ErrAuthenticationError]); service-defined exceptions are generated error
// types.
//
// A process has one node, [DefaultNode].
package robotraconteur
