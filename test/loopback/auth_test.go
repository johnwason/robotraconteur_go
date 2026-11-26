package loopback

import (
	"context"
	"errors"
	"fmt"
	"slices"
	"testing"

	rr "github.com/robotraconteur/robotraconteur_go/robotraconteur"
	ts1 "github.com/robotraconteur/robotraconteur_go/test/gen/com__robotraconteur__testing__testservice1"
)

// authroot reports the authenticated user from inside a service function.
type authroot struct {
	ts1.TestrootDefaultImpl
	ctxs chan context.Context // request contexts kept past the request
}

// Func1 fails with an *rr.Error that has no Code: it must reach the client
// as an error, not as success.
func (a *authroot) Func1(ctx context.Context) error {
	return &rr.Error{Message: "failed without a code"}
}

func (a *authroot) Func3(ctx context.Context, d1, d2 float64) (float64, error) {
	if a.ctxs != nil {
		select {
		case a.ctxs <- ctx:
		default:
		}
	}
	u, err := rr.CurrentAuthenticatedUser(ctx)
	if err != nil {
		return 0, err
	}
	if u.Username != "alice" || !slices.Contains(u.Privileges, "objectlock") || u.LoginTime.IsZero() {
		return 0, rr.NewInvalidOperation(fmt.Sprintf("unexpected user %+v", u))
	}
	return d1 + d2, nil
}

func TestGoUserAuthenticator(t *testing.T) {
	ctx := t.Context()
	auth := rr.UserAuthenticatorFunc(func(username string, cred map[string]any, ctx *rr.ServerContext) (*rr.AuthenticatedUser, error) {
		if ctx == nil {
			return nil, errors.New("no context")
		}
		if username == "alice" && cred["password"] == "secret" {
			return &rr.AuthenticatedUser{Privileges: []string{"objectlock"}}, nil
		}
		if username == "panic" {
			panic("authenticator panic")
		}
		if username == "nocode" {
			return nil, &rr.Error{Message: "rejected without a code"}
		}
		return nil, errors.New("bad password")
	})
	policy := &rr.ServiceSecurityPolicy{Authenticator: auth, Policies: map[string]string{"requirevaliduser": "true"}}
	root := &authroot{ctxs: make(chan context.Context, 1)}
	if _, err := node.RegisterService("go_auth", "com.robotraconteur.testing.TestService1.testroot", root,
		rr.WithSecurityPolicy(policy)); err != nil {
		t.Fatal(err)
	}
	defer node.CloseService("go_auth")
	url := fmt.Sprintf("rr+tcp://localhost:%d?service=go_auth", port)

	for _, c := range []struct{ user, pass string }{{"alice", "wrong"}, {"bob", "secret"}, {"panic", ""}} {
		_, err := node.ConnectService(ctx, url, rr.WithCredentials(c.user, map[string]any{"password": c.pass}))
		if !errors.Is(err, rr.ErrAuthenticationError) {
			t.Errorf("%s: expected AuthenticationError, got %v", c.user, err)
		}
	}
	if _, err := node.ConnectService(ctx, url); err == nil {
		t.Error("expected error connecting without credentials")
	}
	// An authenticator error without a Code must not log the client in
	if o, err := node.ConnectService(ctx, url, rr.WithCredentials("nocode", map[string]any{})); err == nil {
		node.DisconnectService(o)
		t.Error("nocode: login succeeded")
	}

	o, err := node.ConnectService(ctx, url, rr.WithCredentials("alice", map[string]any{"password": "secret"}))
	if err != nil {
		t.Fatal(err)
	}
	defer node.DisconnectService(o)
	v, err := o.(ts1.Testroot).Func3(ctx, 1, 2)
	if err != nil || v != 3 {
		t.Fatalf("Func3 %v %v", v, err)
	}
	// The request context stays usable after the request completed (the
	// authenticated user is copied, not a freed native handle).
	select {
	case rctx := <-root.ctxs:
		u, err := rr.CurrentAuthenticatedUser(rctx)
		if err != nil || u.Username != "alice" || !slices.Contains(u.Privileges, "objectlock") {
			t.Errorf("user after the request: %+v %v", u, err)
		}
	default:
		t.Error("request context not captured")
	}
	if err := o.(ts1.Testroot).Func1(ctx); err == nil {
		t.Error("Func1: an error without a Code was reported as success")
	} else if !errors.Is(err, rr.ErrUnknownError) {
		t.Errorf("Func1: expected UnknownError, got %v", err)
	}
}

// A policy with an authenticator and no Policies requires a valid user.
func TestSecurityPolicyRequiresUserByDefault(t *testing.T) {
	ctx := t.Context()
	auth := rr.UserAuthenticatorFunc(func(username string, cred map[string]any, sc *rr.ServerContext) (*rr.AuthenticatedUser, error) {
		if username == "alice" && cred["password"] == "secret" {
			return &rr.AuthenticatedUser{}, nil
		}
		return nil, errors.New("bad password")
	})
	if _, err := node.RegisterService("go_auth_default", "com.robotraconteur.testing.TestService1.testroot", &authroot{},
		rr.WithSecurityPolicy(&rr.ServiceSecurityPolicy{Authenticator: auth})); err != nil {
		t.Fatal(err)
	}
	defer node.CloseService("go_auth_default")
	url := fmt.Sprintf("rr+tcp://localhost:%d?service=go_auth_default", port)
	if o, err := node.ConnectService(ctx, url); err == nil {
		node.DisconnectService(o)
		t.Error("anonymous client connected to a service with an authenticator and no Policies")
	}
	o, err := node.ConnectService(ctx, url, rr.WithCredentials("alice", map[string]any{"password": "secret"}))
	if err != nil {
		t.Fatal(err)
	}
	node.DisconnectService(o)
}
