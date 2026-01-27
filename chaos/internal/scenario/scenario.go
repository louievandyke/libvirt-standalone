// Package scenario handles loading and executing chaos test scenarios.
package scenario

import (
	"fmt"
	"os"
	"path/filepath"
	"time"

	"gopkg.in/yaml.v3"
)

// Scenario represents a chaos test scenario loaded from YAML.
type Scenario struct {
	Name        string            `yaml:"name"`
	Description string            `yaml:"description"`
	Tags        []string          `yaml:"tags"`
	Timeout     Duration          `yaml:"timeout"`
	Steps       []Step            `yaml:"steps"`
	Cleanup     []Step            `yaml:"cleanup"`
	Metadata    map[string]string `yaml:"metadata"`
}

// Step represents a single step in a scenario.
type Step struct {
	Name     string         `yaml:"name"`
	Action   string         `yaml:"action,omitempty"`   // For inject steps
	Assert   string         `yaml:"assert,omitempty"`   // For assertion steps
	Wait     Duration       `yaml:"wait,omitempty"`     // For wait steps
	Args     map[string]any `yaml:"args,omitempty"`     // Arguments for action/assertion
	OnError  OnErrorBehavior `yaml:"on_error,omitempty"` // What to do on error
	Retries  int            `yaml:"retries,omitempty"`  // Number of retries
	Timeout  Duration       `yaml:"timeout,omitempty"`  // Step-specific timeout
}

// OnErrorBehavior defines what to do when a step fails.
type OnErrorBehavior string

const (
	OnErrorFail     OnErrorBehavior = "fail"     // Stop scenario (default)
	OnErrorContinue OnErrorBehavior = "continue" // Continue to next step
	OnErrorCleanup  OnErrorBehavior = "cleanup"  // Jump to cleanup
)

// Duration wraps time.Duration for YAML unmarshaling.
type Duration time.Duration

// UnmarshalYAML parses duration strings like "15s", "1m", etc.
func (d *Duration) UnmarshalYAML(node *yaml.Node) error {
	var s string
	if err := node.Decode(&s); err != nil {
		return err
	}

	parsed, err := time.ParseDuration(s)
	if err != nil {
		return fmt.Errorf("invalid duration %q: %w", s, err)
	}

	*d = Duration(parsed)
	return nil
}

// Duration returns the underlying time.Duration.
func (d Duration) Duration() time.Duration {
	return time.Duration(d)
}

// StepType returns the type of step based on which field is set.
func (s *Step) StepType() string {
	switch {
	case s.Action != "":
		return "action"
	case s.Assert != "":
		return "assert"
	case s.Wait > 0:
		return "wait"
	default:
		return "unknown"
	}
}

// Validate checks the scenario for errors.
func (s *Scenario) Validate() error {
	if s.Name == "" {
		return fmt.Errorf("scenario name is required")
	}

	if len(s.Steps) == 0 {
		return fmt.Errorf("scenario must have at least one step")
	}

	for i, step := range s.Steps {
		if err := step.Validate(); err != nil {
			return fmt.Errorf("step %d (%s): %w", i+1, step.Name, err)
		}
	}

	for i, step := range s.Cleanup {
		if err := step.Validate(); err != nil {
			return fmt.Errorf("cleanup step %d (%s): %w", i+1, step.Name, err)
		}
	}

	return nil
}

// Validate checks the step for errors.
func (s *Step) Validate() error {
	stepType := s.StepType()

	if stepType == "unknown" {
		return fmt.Errorf("step must have action, assert, or wait")
	}

	if s.OnError != "" && s.OnError != OnErrorFail && s.OnError != OnErrorContinue && s.OnError != OnErrorCleanup {
		return fmt.Errorf("invalid on_error value: %s", s.OnError)
	}

	return nil
}

// Load reads a scenario from a YAML file.
func Load(path string) (*Scenario, error) {
	data, err := os.ReadFile(path)
	if err != nil {
		return nil, fmt.Errorf("reading scenario file: %w", err)
	}

	var scenario Scenario
	if err := yaml.Unmarshal(data, &scenario); err != nil {
		return nil, fmt.Errorf("parsing scenario file: %w", err)
	}

	if err := scenario.Validate(); err != nil {
		return nil, fmt.Errorf("validating scenario: %w", err)
	}

	return &scenario, nil
}

// LoadFromDir searches for scenarios in the given directory.
func LoadFromDir(dir string) ([]*Scenario, error) {
	var scenarios []*Scenario

	err := filepath.Walk(dir, func(path string, info os.FileInfo, err error) error {
		if err != nil {
			return err
		}

		if info.IsDir() {
			return nil
		}

		ext := filepath.Ext(path)
		if ext != ".yaml" && ext != ".yml" {
			return nil
		}

		scenario, err := Load(path)
		if err != nil {
			return fmt.Errorf("loading %s: %w", path, err)
		}

		scenarios = append(scenarios, scenario)
		return nil
	})

	return scenarios, err
}

// FindScenario searches for a scenario by name in standard locations.
func FindScenario(name string, searchPaths []string) (string, error) {
	// Check if name is already a path
	if _, err := os.Stat(name); err == nil {
		return name, nil
	}

	// Check if name has yaml extension
	candidates := []string{name}
	if filepath.Ext(name) == "" {
		candidates = append(candidates, name+".yaml", name+".yml")
	}

	// Search in provided paths
	for _, searchPath := range searchPaths {
		for _, candidate := range candidates {
			path := filepath.Join(searchPath, candidate)
			if _, err := os.Stat(path); err == nil {
				return path, nil
			}
		}
	}

	return "", fmt.Errorf("scenario %q not found in %v", name, searchPaths)
}
