package asserts

import (
	"context"
	"fmt"
	"net/http"
	"sync"
	"time"

	"github.com/libvirt-standalone/chaos/internal/driver"
)

// NomadAPIHealthyAssertion checks that a quorum of Nomad servers respond to API requests.
type NomadAPIHealthyAssertion struct{}

// Name returns the assertion identifier.
func (a *NomadAPIHealthyAssertion) Name() string {
	return "nomad-api-healthy"
}

// Description returns a human-readable description.
func (a *NomadAPIHealthyAssertion) Description() string {
	return "Verify that a quorum of Nomad servers respond to API health checks"
}

// Check queries /v1/agent/health on each server.
func (a *NomadAPIHealthyAssertion) Check(ctx context.Context, actx *driver.AssertContext, args map[string]any) (*Result, error) {
	// Parse timeout from args (default 10s)
	timeout := 10 * time.Second
	if t, ok := args["timeout"].(time.Duration); ok {
		timeout = t
	} else if t, ok := args["timeout"].(string); ok {
		parsed, err := time.ParseDuration(t)
		if err == nil {
			timeout = parsed
		}
	}

	// Parse minimum healthy count (default: quorum = n/2 + 1)
	minHealthy := (len(actx.Cluster.Servers) / 2) + 1
	if m, ok := args["min_healthy"].(int); ok {
		minHealthy = m
	}

	result := NewResult(a.Name(), false, "")
	result.Details["total_servers"] = len(actx.Cluster.Servers)
	result.Details["min_healthy"] = minHealthy
	result.Details["timeout"] = timeout.String()

	start := time.Now()

	// Check all servers in parallel
	type serverResult struct {
		name    string
		healthy bool
		err     error
	}

	var wg sync.WaitGroup
	results := make(chan serverResult, len(actx.Cluster.Servers))

	for _, server := range actx.Cluster.Servers {
		wg.Add(1)
		go func(s driver.Node) {
			defer wg.Done()

			checkCtx, cancel := context.WithTimeout(ctx, timeout)
			defer cancel()

			healthy, err := checkServerHealth(checkCtx, s.PublicIP)
			results <- serverResult{
				name:    s.Name,
				healthy: healthy,
				err:     err,
			}
		}(server)
	}

	wg.Wait()
	close(results)

	// Collect results
	healthyCount := 0
	serverStatuses := make(map[string]string)

	for sr := range results {
		if sr.healthy {
			healthyCount++
			serverStatuses[sr.name] = "healthy"
		} else if sr.err != nil {
			serverStatuses[sr.name] = fmt.Sprintf("error: %v", sr.err)
		} else {
			serverStatuses[sr.name] = "unhealthy"
		}
	}

	result.Details["healthy_count"] = healthyCount
	result.Details["server_statuses"] = serverStatuses
	result.Duration = time.Since(start)
	result.Attempts = 1

	if healthyCount >= minHealthy {
		result.Success = true
		result.Message = fmt.Sprintf("%d/%d servers healthy (quorum: %d)", healthyCount, len(actx.Cluster.Servers), minHealthy)
	} else {
		result.Message = fmt.Sprintf("Only %d/%d servers healthy (need %d for quorum)", healthyCount, len(actx.Cluster.Servers), minHealthy)
	}

	return result, nil
}

// checkServerHealth checks if a server's API is healthy.
func checkServerHealth(ctx context.Context, publicIP string) (bool, error) {
	url := fmt.Sprintf("http://%s:4646/v1/agent/health", publicIP)

	req, err := http.NewRequestWithContext(ctx, "GET", url, nil)
	if err != nil {
		return false, err
	}

	client := &http.Client{Timeout: 5 * time.Second}
	resp, err := client.Do(req)
	if err != nil {
		return false, err
	}
	defer resp.Body.Close()

	// 200 indicates healthy
	return resp.StatusCode == http.StatusOK, nil
}
