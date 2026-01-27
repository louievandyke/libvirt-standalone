// Package actions provides fault injection actions for chaos testing.
package actions

import (
	"context"

	"github.com/libvirt-standalone/chaos/internal/driver"
)

// Action defines a fault injection action that can be executed and rolled back.
type Action interface {
	// Name returns the action identifier (e.g., "kill-leader").
	Name() string

	// Description returns a human-readable description.
	Description() string

	// Execute performs the fault injection.
	Execute(ctx context.Context, actx *driver.ActionContext, args map[string]any) error

	// Rollback reverses the fault injection.
	Rollback(ctx context.Context, actx *driver.ActionContext) error
}

// Result captures the outcome of an action execution.
type Result struct {
	Action    string
	Success   bool
	Error     error
	Message   string
	Duration  int64 // milliseconds
	Rollback  bool  // whether rollback was performed
}
