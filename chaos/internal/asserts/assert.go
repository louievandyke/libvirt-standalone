// Package asserts provides validation assertions for chaos testing.
package asserts

import (
	"context"
	"time"

	"github.com/libvirt-standalone/chaos/internal/driver"
)

// Assertion defines a validation check.
type Assertion interface {
	// Name returns the assertion identifier (e.g., "leader-elected").
	Name() string

	// Description returns a human-readable description.
	Description() string

	// Check validates the expected behavior.
	Check(ctx context.Context, actx *driver.AssertContext, args map[string]any) (*Result, error)
}

// Result captures the outcome of an assertion check.
type Result struct {
	Assertion string
	Success   bool
	Message   string
	Duration  time.Duration
	Attempts  int
	Details   map[string]any
}

// NewResult creates a new assertion result.
func NewResult(assertion string, success bool, message string) *Result {
	return &Result{
		Assertion: assertion,
		Success:   success,
		Message:   message,
		Details:   make(map[string]any),
	}
}
