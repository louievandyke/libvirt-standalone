package asserts

import (
	"context"
	"encoding/json"
	"fmt"
	"net/http"
	"time"

	"github.com/libvirt-standalone/chaos/internal/driver"
)

// LeaderElectedAssertion checks that a Nomad leader is elected within a timeout.
type LeaderElectedAssertion struct{}

// Name returns the assertion identifier.
func (a *LeaderElectedAssertion) Name() string {
	return "leader-elected"
}

// Description returns a human-readable description.
func (a *LeaderElectedAssertion) Description() string {
	return "Verify that a Nomad leader is elected within the specified timeout"
}

// Check polls /v1/status/leader until a leader is found or timeout expires.
func (a *LeaderElectedAssertion) Check(ctx context.Context, actx *driver.AssertContext, args map[string]any) (*Result, error) {
	// Parse timeout from args (default 15s)
	timeout := 15 * time.Second
	if t, ok := args["within"].(time.Duration); ok {
		timeout = t
	} else if t, ok := args["within"].(string); ok {
		parsed, err := time.ParseDuration(t)
		if err == nil {
			timeout = parsed
		}
	}

	// Parse poll interval (default 1s)
	pollInterval := 1 * time.Second
	if p, ok := args["poll"].(time.Duration); ok {
		pollInterval = p
	}

	result := NewResult(a.Name(), false, "")
	result.Details["timeout"] = timeout.String()
	result.Details["poll_interval"] = pollInterval.String()

	start := time.Now()
	deadline := start.Add(timeout)
	attempts := 0

	for time.Now().Before(deadline) {
		attempts++

		// Try each server
		for _, server := range actx.Cluster.Servers {
			addr := fmt.Sprintf("http://%s:4646", server.PublicIP)
			leaderAddr, err := queryLeader(ctx, addr)
			if err == nil && leaderAddr != "" {
				result.Success = true
				result.Message = fmt.Sprintf("Leader elected: %s", leaderAddr)
				result.Duration = time.Since(start)
				result.Attempts = attempts
				result.Details["leader"] = leaderAddr
				result.Details["responding_server"] = server.Name
				return result, nil
			}
		}

		// Wait before next poll
		select {
		case <-ctx.Done():
			result.Message = "Context cancelled"
			result.Duration = time.Since(start)
			result.Attempts = attempts
			return result, ctx.Err()
		case <-time.After(pollInterval):
		}
	}

	result.Message = fmt.Sprintf("No leader elected within %s after %d attempts", timeout, attempts)
	result.Duration = time.Since(start)
	result.Attempts = attempts
	return result, nil
}

// queryLeader queries /v1/status/leader from a specific server.
func queryLeader(ctx context.Context, addr string) (string, error) {
	url := fmt.Sprintf("%s/v1/status/leader", addr)

	req, err := http.NewRequestWithContext(ctx, "GET", url, nil)
	if err != nil {
		return "", err
	}

	client := &http.Client{Timeout: 2 * time.Second}
	resp, err := client.Do(req)
	if err != nil {
		return "", err
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusOK {
		return "", fmt.Errorf("unexpected status: %d", resp.StatusCode)
	}

	var leader string
	if err := json.NewDecoder(resp.Body).Decode(&leader); err != nil {
		return "", err
	}

	return leader, nil
}
