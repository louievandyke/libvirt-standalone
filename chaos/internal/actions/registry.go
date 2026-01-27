package actions

import (
	"fmt"
	"sort"
	"sync"
)

// Registry holds all registered actions.
type Registry struct {
	mu      sync.RWMutex
	actions map[string]Action
}

// DefaultRegistry is the global action registry.
var DefaultRegistry = NewRegistry()

// NewRegistry creates a new action registry.
func NewRegistry() *Registry {
	return &Registry{
		actions: make(map[string]Action),
	}
}

// Register adds an action to the registry.
func (r *Registry) Register(action Action) error {
	r.mu.Lock()
	defer r.mu.Unlock()

	name := action.Name()
	if _, exists := r.actions[name]; exists {
		return fmt.Errorf("action %q already registered", name)
	}

	r.actions[name] = action
	return nil
}

// Get retrieves an action by name.
func (r *Registry) Get(name string) (Action, error) {
	r.mu.RLock()
	defer r.mu.RUnlock()

	action, exists := r.actions[name]
	if !exists {
		return nil, fmt.Errorf("action %q not found", name)
	}
	return action, nil
}

// List returns all registered action names.
func (r *Registry) List() []string {
	r.mu.RLock()
	defer r.mu.RUnlock()

	names := make([]string, 0, len(r.actions))
	for name := range r.actions {
		names = append(names, name)
	}
	sort.Strings(names)
	return names
}

// All returns all registered actions.
func (r *Registry) All() []Action {
	r.mu.RLock()
	defer r.mu.RUnlock()

	actions := make([]Action, 0, len(r.actions))
	for _, action := range r.actions {
		actions = append(actions, action)
	}
	return actions
}

// Register adds an action to the default registry.
func Register(action Action) error {
	return DefaultRegistry.Register(action)
}

// Get retrieves an action from the default registry.
func Get(name string) (Action, error) {
	return DefaultRegistry.Get(name)
}

// List returns all action names from the default registry.
func List() []string {
	return DefaultRegistry.List()
}

func init() {
	// Register all built-in actions
	Register(&KillLeaderAction{})
	Register(&PartitionAction{})
}
