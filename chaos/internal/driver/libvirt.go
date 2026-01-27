package driver

import (
	"context"
	"encoding/json"
	"fmt"
	"net/http"
	"os/exec"
	"strings"
	"time"

	"github.com/libvirt-standalone/chaos/internal/config"
)

// LibvirtDriver implements Driver using Terraform outputs and SSH.
type LibvirtDriver struct {
	config    *config.Config
	sshConfig SSHConfig
}

// NewLibvirtDriver creates a new driver from configuration.
func NewLibvirtDriver(cfg *config.Config) (*LibvirtDriver, error) {
	sshConfig := SSHConfig{
		User:           cfg.SSH.User,
		KeyPath:        cfg.SSH.KeyPath,
		Port:           cfg.SSH.Port,
		ConnectTimeout: time.Duration(cfg.SSH.ConnectTimeout) * time.Second,
	}

	if sshConfig.Port == 0 {
		sshConfig.Port = 22
	}
	if sshConfig.ConnectTimeout == 0 {
		sshConfig.ConnectTimeout = 10 * time.Second
	}

	return &LibvirtDriver{
		config:    cfg,
		sshConfig: sshConfig,
	}, nil
}

// terraformOutput represents the structure of terraform output -json.
type terraformOutput struct {
	ServerPublicIPs  outputValue `json:"server_public_ips"`
	ServerPrivateIPs outputValue `json:"server_private_ips"`
	ClusterInfo      struct {
		Value struct {
			StackName   string `json:"stack_name"`
			ServerCount int    `json:"server_count"`
		} `json:"value"`
	} `json:"cluster_info"`
}

type outputValue struct {
	Value []string `json:"value"`
}

// Discover finds all nodes by parsing terraform outputs.
func (d *LibvirtDriver) Discover(ctx context.Context) (*Cluster, error) {
	workingDir := d.config.Discovery.Terraform.WorkingDir

	// Run terraform output -json
	cmd := exec.CommandContext(ctx, "terraform", "output", "-json")
	cmd.Dir = workingDir

	output, err := cmd.Output()
	if err != nil {
		if exitErr, ok := err.(*exec.ExitError); ok {
			return nil, fmt.Errorf("terraform output failed: %s", string(exitErr.Stderr))
		}
		return nil, fmt.Errorf("running terraform output: %w", err)
	}

	var tfOutput terraformOutput
	if err := json.Unmarshal(output, &tfOutput); err != nil {
		return nil, fmt.Errorf("parsing terraform output: %w", err)
	}

	cluster := &Cluster{
		Name:    d.config.Cluster.Name,
		Servers: make([]Node, 0),
		Clients: make([]Node, 0),
	}

	publicIPs := tfOutput.ServerPublicIPs.Value
	privateIPs := tfOutput.ServerPrivateIPs.Value

	if len(publicIPs) != len(privateIPs) {
		return nil, fmt.Errorf("mismatch between public IPs (%d) and private IPs (%d)",
			len(publicIPs), len(privateIPs))
	}

	for i := range publicIPs {
		cluster.Servers = append(cluster.Servers, Node{
			Name:      fmt.Sprintf("server-%d", i),
			PublicIP:  publicIPs[i],
			PrivateIP: privateIPs[i],
			Role:      RoleServer,
			Index:     i,
			Labels:    make(map[string]string),
		})
	}

	return cluster, nil
}

// SSH opens an SSH connection to a node.
func (d *LibvirtDriver) SSH(ctx context.Context, node Node) (SSHClient, error) {
	return NewSSHClient(ctx, node, d.sshConfig)
}

// GetNomadLeader finds the current Nomad leader by querying the API.
func (d *LibvirtDriver) GetNomadLeader(ctx context.Context, cluster *Cluster) (*Node, error) {
	// Try each server until we get a leader response
	var lastErr error
	for _, server := range cluster.Servers {
		addr := d.GetNomadAddr(server)
		leaderAddr, err := d.queryLeader(ctx, addr)
		if err != nil {
			lastErr = err
			continue
		}

		// leaderAddr is in format "IP:port", extract IP
		leaderIP := strings.Split(leaderAddr, ":")[0]

		// Find the node with this private IP
		for i := range cluster.Servers {
			if cluster.Servers[i].PrivateIP == leaderIP {
				return &cluster.Servers[i], nil
			}
		}

		return nil, fmt.Errorf("leader IP %s not found in cluster nodes", leaderIP)
	}

	if lastErr != nil {
		return nil, fmt.Errorf("could not determine leader: %w", lastErr)
	}
	return nil, fmt.Errorf("could not determine leader: no servers available")
}

// queryLeader queries /v1/status/leader from a specific server.
func (d *LibvirtDriver) queryLeader(ctx context.Context, addr string) (string, error) {
	url := fmt.Sprintf("%s/v1/status/leader", addr)

	req, err := http.NewRequestWithContext(ctx, "GET", url, nil)
	if err != nil {
		return "", err
	}

	client := &http.Client{Timeout: 5 * time.Second}
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

	if leader == "" {
		return "", fmt.Errorf("no leader elected")
	}

	return leader, nil
}

// GetNomadAddr returns the Nomad API address for a node.
func (d *LibvirtDriver) GetNomadAddr(node Node) string {
	// Use configured address if set, otherwise construct from node
	if d.config.Nomad.Address != "" && d.config.Nomad.Address != "http://localhost:4646" {
		return d.config.Nomad.Address
	}
	return fmt.Sprintf("http://%s:4646", node.PublicIP)
}

// Close releases any resources held by the driver.
func (d *LibvirtDriver) Close() error {
	return nil
}
