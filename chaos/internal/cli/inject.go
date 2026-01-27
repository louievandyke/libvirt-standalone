package cli

import (
	"context"
	"fmt"
	"strings"
	"time"

	"github.com/spf13/cobra"

	"github.com/libvirt-standalone/chaos/internal/actions"
	"github.com/libvirt-standalone/chaos/internal/driver"
)

var (
	injectArgs    []string
	injectTimeout time.Duration
)

var injectCmd = &cobra.Command{
	Use:   "inject <action>",
	Short: "Inject a fault into the cluster",
	Long: `Inject a fault into the cluster using the specified action.

Available actions:
  kill-leader   Kill the Nomad leader process (args: signal=TERM|KILL)
  partition     Create network partition (args: source=node, target=node, bidirectional=true)

Examples:
  chaos inject kill-leader
  chaos inject kill-leader --arg signal=KILL
  chaos inject partition --arg source=server-0 --arg target=server-1`,
	Args: cobra.ExactArgs(1),
	RunE: runInject,
}

func init() {
	injectCmd.Flags().StringArrayVarP(&injectArgs, "arg", "a", nil, "action arguments (key=value)")
	injectCmd.Flags().DurationVarP(&injectTimeout, "timeout", "t", 30*time.Second, "action timeout")
	rootCmd.AddCommand(injectCmd)
}

func runInject(cmd *cobra.Command, args []string) error {
	actionName := args[0]

	// Get the action
	action, err := actions.Get(actionName)
	if err != nil {
		fmt.Printf("Available actions: %s\n", strings.Join(actions.List(), ", "))
		return err
	}

	// Parse arguments
	actionArgs, err := parseArgs(injectArgs)
	if err != nil {
		return fmt.Errorf("parsing arguments: %w", err)
	}

	// Create driver and discover cluster
	drv, err := getDriver()
	if err != nil {
		return fmt.Errorf("creating driver: %w", err)
	}
	defer drv.Close()

	ctx, cancel := context.WithTimeout(context.Background(), injectTimeout)
	defer cancel()

	cluster, err := drv.Discover(ctx)
	if err != nil {
		return fmt.Errorf("discovering cluster: %w", err)
	}

	if isVerbose() {
		fmt.Printf("Discovered %d servers\n", len(cluster.Servers))
		for _, s := range cluster.Servers {
			fmt.Printf("  %s: %s (%s)\n", s.Name, s.PublicIP, s.PrivateIP)
		}
	}

	// Execute the action
	actx := driver.NewActionContext(drv, cluster)

	fmt.Printf("Executing action: %s\n", action.Name())
	start := time.Now()

	if err := action.Execute(ctx, actx, actionArgs); err != nil {
		return fmt.Errorf("action failed: %w", err)
	}

	fmt.Printf("Action completed in %v\n", time.Since(start))

	// Store action context for potential rollback
	if err := saveActionState(actx, action.Name()); err != nil {
		fmt.Printf("Warning: could not save state for rollback: %v\n", err)
	}

	return nil
}

// parseArgs converts key=value strings to a map.
func parseArgs(args []string) (map[string]any, error) {
	result := make(map[string]any)

	for _, arg := range args {
		parts := strings.SplitN(arg, "=", 2)
		if len(parts) != 2 {
			return nil, fmt.Errorf("invalid argument %q: must be key=value", arg)
		}

		key := strings.TrimSpace(parts[0])
		value := strings.TrimSpace(parts[1])

		// Try to parse as bool
		switch strings.ToLower(value) {
		case "true":
			result[key] = true
		case "false":
			result[key] = false
		default:
			result[key] = value
		}
	}

	return result, nil
}

// saveActionState persists action context for later rollback.
// For MVP, we just store in a simple state file.
func saveActionState(actx *driver.ActionContext, actionName string) error {
	// For MVP, state is kept in memory during the session
	// A more robust implementation would persist to disk
	lastActionContext = actx
	lastActionName = actionName
	return nil
}

// Package-level state for rollback (MVP implementation)
var (
	lastActionContext *driver.ActionContext
	lastActionName    string
)
