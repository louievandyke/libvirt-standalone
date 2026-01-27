package actions

import (
	"context"
	"fmt"
	"strings"

	"github.com/libvirt-standalone/chaos/internal/driver"
)

// KillLeaderAction kills the Nomad leader process.
type KillLeaderAction struct{}

// Name returns the action identifier.
func (a *KillLeaderAction) Name() string {
	return "kill-leader"
}

// Description returns a human-readable description.
func (a *KillLeaderAction) Description() string {
	return "Kill the Nomad leader process using SIGTERM or SIGKILL"
}

// Execute finds the Nomad leader and kills the process.
func (a *KillLeaderAction) Execute(ctx context.Context, actx *driver.ActionContext, args map[string]any) error {
	// Determine signal to use
	signal := "TERM"
	if s, ok := args["signal"].(string); ok {
		signal = strings.ToUpper(s)
	}

	if signal != "TERM" && signal != "KILL" {
		return fmt.Errorf("invalid signal %q: must be TERM or KILL", signal)
	}

	// Find the leader
	leader, err := actx.Driver.GetNomadLeader(ctx, actx.Cluster)
	if err != nil {
		return fmt.Errorf("finding leader: %w", err)
	}

	// Store for potential rollback info (though we can't really restore a killed process)
	actx.State["killed_node"] = leader.Name
	actx.State["killed_ip"] = leader.PublicIP

	// SSH to the leader and kill the process
	client, err := actx.Driver.SSH(ctx, *leader)
	if err != nil {
		return fmt.Errorf("connecting to leader %s: %w", leader.Name, err)
	}
	defer client.Close()

	// Find and kill the nomad process
	cmd := fmt.Sprintf("pkill -%s nomad", signal)
	stdout, stderr, exitCode, err := client.RunWithSudo(ctx, cmd)
	if err != nil {
		return fmt.Errorf("executing kill command: %w", err)
	}

	// pkill returns 0 if processes were killed, 1 if no processes matched
	if exitCode == 1 {
		return fmt.Errorf("no nomad process found on %s", leader.Name)
	}
	if exitCode != 0 {
		return fmt.Errorf("pkill failed (exit %d): stdout=%s stderr=%s", exitCode, stdout, stderr)
	}

	return nil
}

// Rollback for kill-leader is a no-op (process must be restarted manually or by systemd).
func (a *KillLeaderAction) Rollback(ctx context.Context, actx *driver.ActionContext) error {
	// Check if we can restart the service
	nodeName, ok := actx.State["killed_node"].(string)
	if !ok {
		return fmt.Errorf("no killed node recorded")
	}

	node, err := actx.Cluster.ServerByName(nodeName)
	if err != nil {
		return fmt.Errorf("finding node %s: %w", nodeName, err)
	}

	client, err := actx.Driver.SSH(ctx, *node)
	if err != nil {
		return fmt.Errorf("connecting to %s: %w", nodeName, err)
	}
	defer client.Close()

	// Try to restart via systemd
	_, stderr, exitCode, err := client.RunWithSudo(ctx, "systemctl restart nomad")
	if err != nil {
		return fmt.Errorf("executing restart: %w", err)
	}

	if exitCode != 0 {
		return fmt.Errorf("failed to restart nomad (exit %d): %s", exitCode, stderr)
	}

	return nil
}
