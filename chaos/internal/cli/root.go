// Package cli provides the Cobra command structure for the chaos tool.
package cli

import (
	"fmt"
	"os"

	"github.com/spf13/cobra"

	"github.com/libvirt-standalone/chaos/internal/config"
	"github.com/libvirt-standalone/chaos/internal/driver"
)

var (
	cfgFile string
	verbose bool
	cfg     *config.Config
)

// rootCmd is the base command.
var rootCmd = &cobra.Command{
	Use:   "chaos",
	Short: "Chaos testing tool for Nomad/Consul/Vault clusters",
	Long: `Chaos is a CLI tool for testing the resilience of HashiCorp
Nomad, Consul, and Vault clusters through controlled fault injection.

It discovers cluster nodes via Terraform outputs, connects via SSH,
and performs actions like killing leaders, partitioning networks,
and validating recovery behavior.`,
	PersistentPreRunE: func(cmd *cobra.Command, args []string) error {
		// Skip config loading for commands that don't need it
		switch cmd.Name() {
		case "help", "version", "completion":
			return nil
		}

		// Also skip for report command (reads from file, not cluster)
		if cmd.Name() == "report" {
			return nil
		}

		var err error
		if cfgFile != "" {
			cfg, err = config.Load(cfgFile)
		} else {
			wd, _ := os.Getwd()
			cfg, err = config.LoadFromDir(wd)
		}

		if err != nil {
			return fmt.Errorf("loading config: %w", err)
		}

		return nil
	},
	SilenceUsage: true,
}

// Execute runs the root command.
func Execute() error {
	return rootCmd.Execute()
}

var versionCmd = &cobra.Command{
	Use:   "version",
	Short: "Print the version number",
	Run: func(cmd *cobra.Command, args []string) {
		fmt.Println("chaos v0.1.0")
	},
}

func init() {
	rootCmd.PersistentFlags().StringVarP(&cfgFile, "config", "c", "", "config file (default: chaos.yaml)")
	rootCmd.PersistentFlags().BoolVarP(&verbose, "verbose", "v", false, "verbose output")
	rootCmd.AddCommand(versionCmd)
}

// getDriver creates a driver from the current configuration.
func getDriver() (driver.Driver, error) {
	if cfg == nil {
		return nil, fmt.Errorf("configuration not loaded")
	}
	return driver.NewLibvirtDriver(cfg)
}

// getConfig returns the current configuration.
func getConfig() *config.Config {
	return cfg
}

// isVerbose returns whether verbose output is enabled.
func isVerbose() bool {
	return verbose
}
