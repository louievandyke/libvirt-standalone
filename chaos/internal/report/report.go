// Package report provides reporting and output formatting for chaos tests.
package report

import (
	"time"
)

// EventType categorizes events in the report.
type EventType string

const (
	EventStart   EventType = "start"
	EventSuccess EventType = "success"
	EventFailure EventType = "failure"
	EventError   EventType = "error"
	EventCleanup EventType = "cleanup"
	EventInfo    EventType = "info"
)

// Event represents a single event in the chaos test timeline.
type Event struct {
	Time     time.Time     `json:"time"`
	Type     EventType     `json:"type"`
	Step     string        `json:"step"`
	Message  string        `json:"message"`
	Duration time.Duration `json:"duration,omitempty"`
	Details  map[string]any `json:"details,omitempty"`
}

// Report captures the complete results of a chaos test scenario.
type Report struct {
	Scenario    string        `json:"scenario"`
	Description string        `json:"description,omitempty"`
	StartTime   time.Time     `json:"start_time"`
	EndTime     time.Time     `json:"end_time"`
	Duration    time.Duration `json:"duration"`
	Success     bool          `json:"success"`
	Error       error         `json:"-"`
	ErrorMsg    string        `json:"error,omitempty"`
	Events      []Event       `json:"events"`
	Stats       Stats         `json:"stats"`
}

// Stats provides summary statistics for the report.
type Stats struct {
	TotalSteps     int `json:"total_steps"`
	SuccessSteps   int `json:"success_steps"`
	FailedSteps    int `json:"failed_steps"`
	CleanupSteps   int `json:"cleanup_steps"`
}

// NewReport creates a new report for a scenario.
func NewReport(scenario string) *Report {
	return &Report{
		Scenario:  scenario,
		StartTime: time.Now(),
		Events:    make([]Event, 0),
	}
}

// AddEvent appends an event to the report.
func (r *Report) AddEvent(e Event) {
	if e.Time.IsZero() {
		e.Time = time.Now()
	}
	r.Events = append(r.Events, e)

	// Update stats
	r.Stats.TotalSteps++
	switch e.Type {
	case EventSuccess:
		r.Stats.SuccessSteps++
	case EventFailure, EventError:
		r.Stats.FailedSteps++
	case EventCleanup:
		r.Stats.CleanupSteps++
	}
}

// Finish marks the report as complete.
func (r *Report) Finish() {
	r.EndTime = time.Now()
	r.Duration = r.EndTime.Sub(r.StartTime)
	if r.Error != nil {
		r.ErrorMsg = r.Error.Error()
	}
}
