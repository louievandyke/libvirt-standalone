package asserts

import (
	"fmt"
	"sort"
	"sync"
)

// Registry holds all registered assertions.
type Registry struct {
	mu         sync.RWMutex
	assertions map[string]Assertion
}

// DefaultRegistry is the global assertion registry.
var DefaultRegistry = NewRegistry()

// NewRegistry creates a new assertion registry.
func NewRegistry() *Registry {
	return &Registry{
		assertions: make(map[string]Assertion),
	}
}

// Register adds an assertion to the registry.
func (r *Registry) Register(assertion Assertion) error {
	r.mu.Lock()
	defer r.mu.Unlock()

	name := assertion.Name()
	if _, exists := r.assertions[name]; exists {
		return fmt.Errorf("assertion %q already registered", name)
	}

	r.assertions[name] = assertion
	return nil
}

// Get retrieves an assertion by name.
func (r *Registry) Get(name string) (Assertion, error) {
	r.mu.RLock()
	defer r.mu.RUnlock()

	assertion, exists := r.assertions[name]
	if !exists {
		return nil, fmt.Errorf("assertion %q not found", name)
	}
	return assertion, nil
}

// List returns all registered assertion names.
func (r *Registry) List() []string {
	r.mu.RLock()
	defer r.mu.RUnlock()

	names := make([]string, 0, len(r.assertions))
	for name := range r.assertions {
		names = append(names, name)
	}
	sort.Strings(names)
	return names
}

// All returns all registered assertions.
func (r *Registry) All() []Assertion {
	r.mu.RLock()
	defer r.mu.RUnlock()

	assertions := make([]Assertion, 0, len(r.assertions))
	for _, assertion := range r.assertions {
		assertions = append(assertions, assertion)
	}
	return assertions
}

// Register adds an assertion to the default registry.
func Register(assertion Assertion) error {
	return DefaultRegistry.Register(assertion)
}

// Get retrieves an assertion from the default registry.
func Get(name string) (Assertion, error) {
	return DefaultRegistry.Get(name)
}

// List returns all assertion names from the default registry.
func List() []string {
	return DefaultRegistry.List()
}

func init() {
	// Register all built-in assertions
	Register(&LeaderElectedAssertion{})
	Register(&NomadAPIHealthyAssertion{})
}
