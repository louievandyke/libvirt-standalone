package cli

import (
	"context"
	"fmt"
	"os"
	"path/filepath"
	"time"

	"github.com/spf13/cobra"

	"github.com/libvirt-standalone/chaos/internal/scenario"
)

var (
	runTimeout     time.Duration
	runScenarioDir string
	runOutputFile  string
	runOutputJSON  bool
)

var runCmd = &cobra.Command{
	Use:   "run <scenario>",
	Short: "Run a chaos scenario",
	Long: `Run a chaos scenario from a YAML file.

Scenarios define a series of steps including:
  - Actions (inject faults)
  - Assertions (validate state)
  - Waits (pause between steps)

The scenario path can be:
  - A full path to a YAML file
  - A name to search in scenarios/ directory
  - A relative path like raft/leader-failover

Examples:
  chaos run scenarios/raft/leader-failover.yaml
  chaos run raft/leader-failover
  chaos run leader-failover --timeout 5m`,
	Args: cobra.ExactArgs(1),
	RunE: runScenario,
}

func init() {
	runCmd.Flags().DurationVarP(&runTimeout, "timeout", "t", 5*time.Minute, "scenario timeout")
	runCmd.Flags().StringVarP(&runScenarioDir, "scenarios", "s", "", "scenarios directory (default: ./scenarios)")
	runCmd.Flags().StringVarP(&runOutputFile, "output", "o", "", "write report to file")
	runCmd.Flags().BoolVar(&runOutputJSON, "json", false, "output report as JSON")
	rootCmd.AddCommand(runCmd)
}

func runScenario(cmd *cobra.Command, args []string) error {
	scenarioName := args[0]

	// Determine search paths
	searchPaths := []string{"."}

	if runScenarioDir != "" {
		searchPaths = append(searchPaths, runScenarioDir)
	}

	// Add default scenarios directory relative to config
	wd, _ := os.Getwd()
	searchPaths = append(searchPaths,
		filepath.Join(wd, "scenarios"),
		filepath.Join(wd, "chaos", "scenarios"),
	)

	// Find the scenario file
	scenarioPath, err := scenario.FindScenario(scenarioName, searchPaths)
	if err != nil {
		return err
	}

	// Load the scenario
	scen, err := scenario.Load(scenarioPath)
	if err != nil {
		return fmt.Errorf("loading scenario: %w", err)
	}

	fmt.Printf("Running scenario: %s\n", scen.Name)
	if scen.Description != "" {
		fmt.Printf("Description: %s\n", scen.Description)
	}
	fmt.Printf("Steps: %d\n", len(scen.Steps))
	fmt.Println()

	// Create driver and discover cluster
	drv, err := getDriver()
	if err != nil {
		return fmt.Errorf("creating driver: %w", err)
	}
	defer drv.Close()

	ctx, cancel := context.WithTimeout(context.Background(), runTimeout)
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
		fmt.Println()
	}

	// Create and run the scenario
	runner := scenario.NewRunner(drv, cluster, isVerbose())
	report, err := runner.Run(ctx, scen)

	// Print or save report
	if runOutputJSON {
		output := report.FormatJSON()
		if runOutputFile != "" {
			if err := os.WriteFile(runOutputFile, []byte(output), 0644); err != nil {
				return fmt.Errorf("writing report: %w", err)
			}
			fmt.Printf("Report written to %s\n", runOutputFile)
		} else {
			fmt.Println(output)
		}
	} else {
		output := report.FormatTable()
		if runOutputFile != "" {
			if err := os.WriteFile(runOutputFile, []byte(output), 0644); err != nil {
				return fmt.Errorf("writing report: %w", err)
			}
			fmt.Printf("Report written to %s\n", runOutputFile)
		} else {
			fmt.Println(output)
		}
	}

	// Return error if scenario failed
	if err != nil {
		return err
	}
	if !report.Success {
		return fmt.Errorf("scenario failed")
	}

	return nil
}
