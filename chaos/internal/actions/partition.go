package actions

import (
	"context"
	"fmt"

	"github.com/libvirt-standalone/chaos/internal/driver"
)

// PartitionAction creates a network partition between nodes using iptables.
type PartitionAction struct{}

// Name returns the action identifier.
func (a *PartitionAction) Name() string {
	return "partition"
}

// Description returns a human-readable description.
func (a *PartitionAction) Description() string {
	return "Create a network partition between two nodes using iptables DROP rules"
}

// Execute creates iptables rules to block traffic between nodes.
func (a *PartitionAction) Execute(ctx context.Context, actx *driver.ActionContext, args map[string]any) error {
	// Get source and target nodes
	sourceArg, ok := args["source"].(string)
	if !ok {
		return fmt.Errorf("source node is required")
	}

	targetArg, ok := args["target"].(string)
	if !ok {
		return fmt.Errorf("target node is required")
	}

	// Bidirectional by default
	bidirectional := true
	if b, ok := args["bidirectional"].(bool); ok {
		bidirectional = b
	}

	// Find nodes
	source, err := actx.Cluster.ServerByName(sourceArg)
	if err != nil {
		return fmt.Errorf("finding source node: %w", err)
	}

	target, err := actx.Cluster.ServerByName(targetArg)
	if err != nil {
		return fmt.Errorf("finding target node: %w", err)
	}

	// Store state for rollback
	actx.State["source_node"] = source.Name
	actx.State["target_node"] = target.Name
	actx.State["source_ip"] = source.PrivateIP
	actx.State["target_ip"] = target.PrivateIP
	actx.State["bidirectional"] = bidirectional

	// Add iptables rules on source to block target
	if err := a.addPartitionRules(ctx, actx.Driver, *source, target.PrivateIP); err != nil {
		return fmt.Errorf("adding rules on %s: %w", source.Name, err)
	}

	// If bidirectional, add rules on target to block source
	if bidirectional {
		if err := a.addPartitionRules(ctx, actx.Driver, *target, source.PrivateIP); err != nil {
			// Rollback the first set of rules
			a.removePartitionRules(ctx, actx.Driver, *source, target.PrivateIP)
			return fmt.Errorf("adding rules on %s: %w", target.Name, err)
		}
	}

	return nil
}

// addPartitionRules adds iptables DROP rules to block an IP.
func (a *PartitionAction) addPartitionRules(ctx context.Context, drv driver.Driver, node driver.Node, blockIP string) error {
	client, err := drv.SSH(ctx, node)
	if err != nil {
		return fmt.Errorf("connecting to %s: %w", node.Name, err)
	}
	defer client.Close()

	// Add rules to block incoming and outgoing traffic
	rules := []string{
		fmt.Sprintf("iptables -I INPUT -s %s -j DROP -m comment --comment chaos-partition", blockIP),
		fmt.Sprintf("iptables -I OUTPUT -d %s -j DROP -m comment --comment chaos-partition", blockIP),
	}

	for _, rule := range rules {
		_, stderr, exitCode, err := client.RunWithSudo(ctx, rule)
		if err != nil {
			return fmt.Errorf("executing %q: %w", rule, err)
		}
		if exitCode != 0 {
			return fmt.Errorf("iptables failed (exit %d): %s", exitCode, stderr)
		}
	}

	return nil
}

// removePartitionRules removes the iptables DROP rules.
func (a *PartitionAction) removePartitionRules(ctx context.Context, drv driver.Driver, node driver.Node, blockIP string) error {
	client, err := drv.SSH(ctx, node)
	if err != nil {
		return fmt.Errorf("connecting to %s: %w", node.Name, err)
	}
	defer client.Close()

	// Remove rules (use -D instead of -I)
	rules := []string{
		fmt.Sprintf("iptables -D INPUT -s %s -j DROP -m comment --comment chaos-partition", blockIP),
		fmt.Sprintf("iptables -D OUTPUT -d %s -j DROP -m comment --comment chaos-partition", blockIP),
	}

	var lastErr error
	for _, rule := range rules {
		_, stderr, exitCode, err := client.RunWithSudo(ctx, rule)
		if err != nil {
			lastErr = fmt.Errorf("executing %q: %w", rule, err)
			continue
		}
		if exitCode != 0 {
			lastErr = fmt.Errorf("iptables failed (exit %d): %s", exitCode, stderr)
		}
	}

	return lastErr
}

// Rollback removes the iptables rules.
func (a *PartitionAction) Rollback(ctx context.Context, actx *driver.ActionContext) error {
	sourceName, _ := actx.State["source_node"].(string)
	targetName, _ := actx.State["target_node"].(string)
	sourceIP, _ := actx.State["source_ip"].(string)
	targetIP, _ := actx.State["target_ip"].(string)
	bidirectional, _ := actx.State["bidirectional"].(bool)

	if sourceName == "" || targetName == "" {
		return fmt.Errorf("partition state not recorded")
	}

	source, err := actx.Cluster.ServerByName(sourceName)
	if err != nil {
		return fmt.Errorf("finding source node: %w", err)
	}

	target, err := actx.Cluster.ServerByName(targetName)
	if err != nil {
		return fmt.Errorf("finding target node: %w", err)
	}

	// Remove rules on source
	if err := a.removePartitionRules(ctx, actx.Driver, *source, targetIP); err != nil {
		return fmt.Errorf("removing rules on %s: %w", source.Name, err)
	}

	// Remove rules on target if bidirectional
	if bidirectional {
		if err := a.removePartitionRules(ctx, actx.Driver, *target, sourceIP); err != nil {
			return fmt.Errorf("removing rules on %s: %w", target.Name, err)
		}
	}

	return nil
}
