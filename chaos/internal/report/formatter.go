package report

import (
	"encoding/json"
	"fmt"
	"strings"
)

// FormatTable returns a human-readable table format of the report.
func (r *Report) FormatTable() string {
	r.Finish()

	var sb strings.Builder

	// Header
	sb.WriteString("╔════════════════════════════════════════════════════════════════╗\n")
	sb.WriteString(fmt.Sprintf("║ Scenario: %-53s ║\n", truncate(r.Scenario, 53)))
	if r.Description != "" {
		sb.WriteString(fmt.Sprintf("║ %-64s ║\n", truncate(r.Description, 64)))
	}
	sb.WriteString("╠════════════════════════════════════════════════════════════════╣\n")

	// Summary
	status := "✓ PASSED"
	if !r.Success {
		status = "✗ FAILED"
	}
	sb.WriteString(fmt.Sprintf("║ Status: %-56s ║\n", status))
	sb.WriteString(fmt.Sprintf("║ Duration: %-54s ║\n", r.Duration.String()))
	sb.WriteString(fmt.Sprintf("║ Steps: %d total, %d success, %d failed, %d cleanup%-13s║\n",
		r.Stats.TotalSteps, r.Stats.SuccessSteps, r.Stats.FailedSteps, r.Stats.CleanupSteps, ""))
	sb.WriteString("╠════════════════════════════════════════════════════════════════╣\n")

	// Events
	sb.WriteString("║ Timeline:                                                      ║\n")
	sb.WriteString("╟────────────────────────────────────────────────────────────────╢\n")

	for _, e := range r.Events {
		icon := eventIcon(e.Type)
		timestamp := e.Time.Format("15:04:05")
		step := truncate(e.Step, 20)
		msg := truncate(e.Message, 30)

		line := fmt.Sprintf("║ %s %s %-20s %-30s ║\n", icon, timestamp, step, msg)
		sb.WriteString(line)
	}

	// Footer
	sb.WriteString("╚════════════════════════════════════════════════════════════════╝\n")

	if r.Error != nil {
		sb.WriteString(fmt.Sprintf("\nError: %v\n", r.Error))
	}

	return sb.String()
}

// FormatJSON returns a JSON representation of the report.
func (r *Report) FormatJSON() string {
	r.Finish()

	data, err := json.MarshalIndent(r, "", "  ")
	if err != nil {
		return fmt.Sprintf(`{"error": "failed to marshal report: %s"}`, err)
	}
	return string(data)
}

// FormatCompact returns a single-line summary of the report.
func (r *Report) FormatCompact() string {
	r.Finish()

	status := "PASS"
	if !r.Success {
		status = "FAIL"
	}

	return fmt.Sprintf("[%s] %s - %d steps in %s",
		status, r.Scenario, r.Stats.TotalSteps, r.Duration)
}

// FormatMarkdown returns a markdown-formatted report.
func (r *Report) FormatMarkdown() string {
	r.Finish()

	var sb strings.Builder

	// Header
	sb.WriteString(fmt.Sprintf("# Chaos Test Report: %s\n\n", r.Scenario))

	if r.Description != "" {
		sb.WriteString(fmt.Sprintf("_%s_\n\n", r.Description))
	}

	// Summary
	status := "✅ **PASSED**"
	if !r.Success {
		status = "❌ **FAILED**"
	}
	sb.WriteString("## Summary\n\n")
	sb.WriteString(fmt.Sprintf("- **Status**: %s\n", status))
	sb.WriteString(fmt.Sprintf("- **Duration**: %s\n", r.Duration))
	sb.WriteString(fmt.Sprintf("- **Steps**: %d total, %d success, %d failed\n\n",
		r.Stats.TotalSteps, r.Stats.SuccessSteps, r.Stats.FailedSteps))

	// Timeline
	sb.WriteString("## Timeline\n\n")
	sb.WriteString("| Time | Status | Step | Message |\n")
	sb.WriteString("|------|--------|------|--------|\n")

	for _, e := range r.Events {
		icon := eventIcon(e.Type)
		timestamp := e.Time.Format("15:04:05")
		sb.WriteString(fmt.Sprintf("| %s | %s | %s | %s |\n",
			timestamp, icon, e.Step, e.Message))
	}

	sb.WriteString("\n")

	if r.Error != nil {
		sb.WriteString(fmt.Sprintf("## Error\n\n```\n%v\n```\n", r.Error))
	}

	return sb.String()
}

// eventIcon returns an icon for the event type.
func eventIcon(t EventType) string {
	switch t {
	case EventStart:
		return "▶"
	case EventSuccess:
		return "✓"
	case EventFailure:
		return "✗"
	case EventError:
		return "!"
	case EventCleanup:
		return "↺"
	case EventInfo:
		return "•"
	default:
		return " "
	}
}

// truncate shortens a string to max length with ellipsis.
func truncate(s string, max int) string {
	if len(s) <= max {
		return s
	}
	if max <= 3 {
		return s[:max]
	}
	return s[:max-3] + "..."
}
