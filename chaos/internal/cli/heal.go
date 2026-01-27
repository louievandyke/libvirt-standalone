package cli

import (
	"context"
	"fmt"
	"time"

	"github.com/spf13/cobra"

	"github.com/libvirt-standalone/chaos/internal/actions"
)

var healTimeout time.Duration

var healCmd = &cobra.Command{
	Use:   "heal",
	Short: "Rollback the last injected fault",
	Long: `Heal attempts to rollback the last injected fault.

This command will:
  - For kill-leader: restart the Nomad service via systemd
  - For partition: remove the iptables DROP rules

Note: heal can only rollback the most recent inject action from this session.`,
	Args: cobra.NoArgs,
	RunE: runHeal,
}

func init() {
	healCmd.Flags().DurationVarP(&healTimeout, "timeout", "t", 30*time.Second, "rollback timeout")
	rootCmd.AddCommand(healCmd)
}

func runHeal(cmd *cobra.Command, args []string) error {
	if lastActionContext == nil || lastActionName == "" {
		return fmt.Errorf("no previous action to heal (state is session-local)")
	}

	// Get the action
	action, err := actions.Get(lastActionName)
	if err != nil {
		return fmt.Errorf("action %q not found: %w", lastActionName, err)
	}

	ctx, cancel := context.WithTimeout(context.Background(), healTimeout)
	defer cancel()

	fmt.Printf("Rolling back action: %s\n", action.Name())
	start := time.Now()

	if err := action.Rollback(ctx, lastActionContext); err != nil {
		return fmt.Errorf("rollback failed: %w", err)
	}

	fmt.Printf("Rollback completed in %v\n", time.Since(start))

	// Clear state
	lastActionContext = nil
	lastActionName = ""

	return nil
}
