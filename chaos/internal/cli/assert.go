package cli

import (
	"context"
	"fmt"
	"strings"
	"time"

	"github.com/spf13/cobra"

	"github.com/libvirt-standalone/chaos/internal/asserts"
	"github.com/libvirt-standalone/chaos/internal/driver"
)

var (
	assertArgs    []string
	assertTimeout time.Duration
	assertWithin  time.Duration
)

var assertCmd = &cobra.Command{
	Use:   "assert <assertion>",
	Short: "Run an assertion to validate cluster state",
	Long: `Run an assertion to validate that the cluster is in the expected state.

Available assertions:
  leader-elected     Check that a Nomad leader is elected
  nomad-api-healthy  Check that a quorum of servers respond to API requests

Examples:
  chaos assert nomad-api-healthy
  chaos assert leader-elected --within 15s
  chaos assert nomad-api-healthy --arg min_healthy=2`,
	Args: cobra.ExactArgs(1),
	RunE: runAssert,
}

func init() {
	assertCmd.Flags().StringArrayVarP(&assertArgs, "arg", "a", nil, "assertion arguments (key=value)")
	assertCmd.Flags().DurationVarP(&assertTimeout, "timeout", "t", 30*time.Second, "assertion timeout")
	assertCmd.Flags().DurationVar(&assertWithin, "within", 0, "maximum time to wait for assertion to pass (polls)")
	rootCmd.AddCommand(assertCmd)
}

func runAssert(cmd *cobra.Command, args []string) error {
	assertionName := args[0]

	// Get the assertion
	assertion, err := asserts.Get(assertionName)
	if err != nil {
		fmt.Printf("Available assertions: %s\n", strings.Join(asserts.List(), ", "))
		return err
	}

	// Parse arguments
	assertionArgs, err := parseAssertArgs(assertArgs)
	if err != nil {
		return fmt.Errorf("parsing arguments: %w", err)
	}

	// Add --within to args if specified
	if assertWithin > 0 {
		assertionArgs["within"] = assertWithin
	}

	// Create driver and discover cluster
	drv, err := getDriver()
	if err != nil {
		return fmt.Errorf("creating driver: %w", err)
	}
	defer drv.Close()

	ctx, cancel := context.WithTimeout(context.Background(), assertTimeout)
	defer cancel()

	cluster, err := drv.Discover(ctx)
	if err != nil {
		return fmt.Errorf("discovering cluster: %w", err)
	}

	if isVerbose() {
		fmt.Printf("Discovered %d servers\n", len(cluster.Servers))
	}

	// Run the assertion
	actx := driver.NewAssertContext(drv, cluster)

	fmt.Printf("Running assertion: %s\n", assertion.Name())

	result, err := assertion.Check(ctx, actx, assertionArgs)
	if err != nil {
		return fmt.Errorf("assertion error: %w", err)
	}

	// Print result
	if result.Success {
		fmt.Printf("✓ PASS: %s\n", result.Message)
	} else {
		fmt.Printf("✗ FAIL: %s\n", result.Message)
	}

	if isVerbose() {
		fmt.Printf("  Duration: %v\n", result.Duration)
		fmt.Printf("  Attempts: %d\n", result.Attempts)
		for k, v := range result.Details {
			fmt.Printf("  %s: %v\n", k, v)
		}
	}

	if !result.Success {
		return fmt.Errorf("assertion failed")
	}

	return nil
}

// parseAssertArgs converts key=value strings to a map, handling int values.
func parseAssertArgs(args []string) (map[string]any, error) {
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
			continue
		case "false":
			result[key] = false
			continue
		}

		// Try to parse as int
		var intVal int
		if _, err := fmt.Sscanf(value, "%d", &intVal); err == nil {
			result[key] = intVal
			continue
		}

		// Try to parse as duration
		if d, err := time.ParseDuration(value); err == nil {
			result[key] = d
			continue
		}

		// Default to string
		result[key] = value
	}

	return result, nil
}
