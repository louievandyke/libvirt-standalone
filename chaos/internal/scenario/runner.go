package scenario

import (
	"context"
	"fmt"
	"time"

	"github.com/libvirt-standalone/chaos/internal/actions"
	"github.com/libvirt-standalone/chaos/internal/asserts"
	"github.com/libvirt-standalone/chaos/internal/driver"
	"github.com/libvirt-standalone/chaos/internal/report"
)

// Runner executes scenarios.
type Runner struct {
	driver  driver.Driver
	cluster *driver.Cluster
	verbose bool
}

// NewRunner creates a new scenario runner.
func NewRunner(drv driver.Driver, cluster *driver.Cluster, verbose bool) *Runner {
	return &Runner{
		driver:  drv,
		cluster: cluster,
		verbose: verbose,
	}
}

// Run executes a scenario and returns a report.
func (r *Runner) Run(ctx context.Context, scenario *Scenario) (*report.Report, error) {
	rep := report.NewReport(scenario.Name)
	rep.Description = scenario.Description

	// Apply scenario timeout
	if scenario.Timeout > 0 {
		var cancel context.CancelFunc
		ctx, cancel = context.WithTimeout(ctx, scenario.Timeout.Duration())
		defer cancel()
	}

	// Track executed actions for cleanup
	var executedActions []*driver.ActionContext

	// Execute steps
	r.log("Starting scenario: %s", scenario.Name)
	runCleanup := false

	for i, step := range scenario.Steps {
		select {
		case <-ctx.Done():
			rep.AddEvent(report.Event{
				Time:    time.Now(),
				Type:    report.EventError,
				Step:    step.Name,
				Message: "Context cancelled",
			})
			runCleanup = true
			break
		default:
		}

		if runCleanup {
			break
		}

		r.log("Step %d: %s", i+1, step.Name)

		result, actx, err := r.executeStep(ctx, &step)
		if actx != nil {
			executedActions = append(executedActions, actx)
		}

		rep.AddEvent(report.Event{
			Time:     time.Now(),
			Type:     result.EventType(),
			Step:     step.Name,
			Message:  result.Message,
			Duration: result.Duration,
		})

		if err != nil || !result.Success {
			switch step.OnError {
			case OnErrorContinue:
				r.log("  Step failed, continuing: %v", err)
				continue
			case OnErrorCleanup:
				r.log("  Step failed, running cleanup: %v", err)
				runCleanup = true
			default: // OnErrorFail
				r.log("  Step failed, aborting: %v", err)
				rep.Success = false
				rep.Error = err
				r.runCleanup(ctx, scenario.Cleanup, executedActions, rep)
				return rep, err
			}
		}
	}

	// Run cleanup steps
	r.runCleanup(ctx, scenario.Cleanup, executedActions, rep)

	rep.Success = true
	r.log("Scenario completed successfully")
	return rep, nil
}

// executeStep runs a single step.
func (r *Runner) executeStep(ctx context.Context, step *Step) (*StepResult, *driver.ActionContext, error) {
	// Apply step timeout
	if step.Timeout > 0 {
		var cancel context.CancelFunc
		ctx, cancel = context.WithTimeout(ctx, step.Timeout.Duration())
		defer cancel()
	}

	start := time.Now()
	var result *StepResult
	var actx *driver.ActionContext
	var err error

	retries := step.Retries
	if retries < 1 {
		retries = 1
	}

	for attempt := 1; attempt <= retries; attempt++ {
		switch step.StepType() {
		case "action":
			result, actx, err = r.executeAction(ctx, step)
		case "assert":
			result, err = r.executeAssert(ctx, step)
		case "wait":
			result, err = r.executeWait(ctx, step)
		default:
			err = fmt.Errorf("unknown step type")
		}

		if err == nil && result.Success {
			break
		}

		if attempt < retries {
			r.log("  Retry %d/%d after failure", attempt, retries)
			time.Sleep(time.Second)
		}
	}

	result.Duration = time.Since(start)
	return result, actx, err
}

// executeAction runs an action step.
func (r *Runner) executeAction(ctx context.Context, step *Step) (*StepResult, *driver.ActionContext, error) {
	action, err := actions.Get(step.Action)
	if err != nil {
		return &StepResult{Success: false, Message: err.Error()}, nil, err
	}

	actx := driver.NewActionContext(r.driver, r.cluster)

	if err := action.Execute(ctx, actx, step.Args); err != nil {
		return &StepResult{Success: false, Message: err.Error()}, actx, err
	}

	// Store action name for rollback
	actx.State["_action_name"] = step.Action

	return &StepResult{Success: true, Message: fmt.Sprintf("Executed %s", step.Action)}, actx, nil
}

// executeAssert runs an assertion step.
func (r *Runner) executeAssert(ctx context.Context, step *Step) (*StepResult, error) {
	assertion, err := asserts.Get(step.Assert)
	if err != nil {
		return &StepResult{Success: false, Message: err.Error()}, err
	}

	actx := driver.NewAssertContext(r.driver, r.cluster)

	result, err := assertion.Check(ctx, actx, step.Args)
	if err != nil {
		return &StepResult{Success: false, Message: err.Error()}, err
	}

	return &StepResult{Success: result.Success, Message: result.Message}, nil
}

// executeWait runs a wait step.
func (r *Runner) executeWait(ctx context.Context, step *Step) (*StepResult, error) {
	r.log("  Waiting %v", step.Wait.Duration())

	select {
	case <-ctx.Done():
		return &StepResult{Success: false, Message: "Wait interrupted"}, ctx.Err()
	case <-time.After(step.Wait.Duration()):
		return &StepResult{Success: true, Message: fmt.Sprintf("Waited %v", step.Wait.Duration())}, nil
	}
}

// runCleanup executes cleanup steps and rolls back actions.
func (r *Runner) runCleanup(ctx context.Context, cleanupSteps []Step, executedActions []*driver.ActionContext, rep *report.Report) {
	r.log("Running cleanup...")

	// First, run explicit cleanup steps
	for i, step := range cleanupSteps {
		r.log("Cleanup step %d: %s", i+1, step.Name)

		result, _, err := r.executeStep(ctx, &step)
		rep.AddEvent(report.Event{
			Time:     time.Now(),
			Type:     report.EventCleanup,
			Step:     step.Name,
			Message:  result.Message,
			Duration: result.Duration,
		})

		if err != nil {
			r.log("  Cleanup step failed: %v", err)
		}
	}

	// Then, rollback executed actions in reverse order
	for i := len(executedActions) - 1; i >= 0; i-- {
		actx := executedActions[i]
		actionName, _ := actx.State["_action_name"].(string)
		if actionName == "" {
			continue
		}

		action, err := actions.Get(actionName)
		if err != nil {
			r.log("  Cannot find action %s for rollback", actionName)
			continue
		}

		r.log("  Rolling back %s", actionName)
		if err := action.Rollback(ctx, actx); err != nil {
			r.log("  Rollback failed: %v", err)
			rep.AddEvent(report.Event{
				Time:    time.Now(),
				Type:    report.EventError,
				Step:    fmt.Sprintf("rollback-%s", actionName),
				Message: err.Error(),
			})
		} else {
			rep.AddEvent(report.Event{
				Time:    time.Now(),
				Type:    report.EventCleanup,
				Step:    fmt.Sprintf("rollback-%s", actionName),
				Message: "Rollback successful",
			})
		}
	}
}

func (r *Runner) log(format string, args ...any) {
	if r.verbose {
		fmt.Printf(format+"\n", args...)
	}
}

// StepResult captures the outcome of a step execution.
type StepResult struct {
	Success  bool
	Message  string
	Duration time.Duration
}

// EventType returns the appropriate event type for this result.
func (r *StepResult) EventType() report.EventType {
	if r.Success {
		return report.EventSuccess
	}
	return report.EventFailure
}
