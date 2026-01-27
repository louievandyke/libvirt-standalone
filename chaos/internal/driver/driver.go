// Package driver provides node discovery and SSH access to cluster nodes.
package driver

import (
	"context"
	"fmt"
	"io"
)

// NodeRole identifies whether a node is a server or client.
type NodeRole string

const (
	RoleServer NodeRole = "server"
	RoleClient NodeRole = "client"
)

// Node represents a single node in the cluster.
type Node struct {
	Name      string            // Friendly name (e.g., "server-0")
	PublicIP  string            // IP for SSH access
	PrivateIP string            // IP for intra-cluster communication
	Role      NodeRole          // server or client
	Index     int               // Node index within role
	Labels    map[string]string // Additional metadata
}

// Cluster represents a discovered cluster.
type Cluster struct {
	Name    string
	Servers []Node
	Clients []Node
}

// AllNodes returns all nodes in the cluster.
func (c *Cluster) AllNodes() []Node {
	nodes := make([]Node, 0, len(c.Servers)+len(c.Clients))
	nodes = append(nodes, c.Servers...)
	nodes = append(nodes, c.Clients...)
	return nodes
}

// ServerByIndex returns a server node by index.
func (c *Cluster) ServerByIndex(idx int) (*Node, error) {
	if idx < 0 || idx >= len(c.Servers) {
		return nil, fmt.Errorf("server index %d out of range (have %d servers)", idx, len(c.Servers))
	}
	return &c.Servers[idx], nil
}

// ServerByName returns a server node by name.
func (c *Cluster) ServerByName(name string) (*Node, error) {
	for i := range c.Servers {
		if c.Servers[i].Name == name {
			return &c.Servers[i], nil
		}
	}
	return nil, fmt.Errorf("server %q not found", name)
}

// SSHClient wraps an SSH connection to a node.
type SSHClient interface {
	// Run executes a command and returns stdout, stderr, and exit code.
	Run(ctx context.Context, cmd string) (stdout, stderr string, exitCode int, err error)

	// RunWithSudo executes a command with sudo.
	RunWithSudo(ctx context.Context, cmd string) (stdout, stderr string, exitCode int, err error)

	// Stream executes a command and streams output.
	Stream(ctx context.Context, cmd string, stdout, stderr io.Writer) (exitCode int, err error)

	// Close closes the SSH connection.
	Close() error
}

// Driver provides node discovery and SSH access.
type Driver interface {
	// Discover finds all nodes in the cluster.
	Discover(ctx context.Context) (*Cluster, error)

	// SSH opens an SSH connection to a node.
	SSH(ctx context.Context, node Node) (SSHClient, error)

	// GetNomadLeader finds the current Nomad leader.
	GetNomadLeader(ctx context.Context, cluster *Cluster) (*Node, error)

	// GetNomadAddr returns the Nomad API address for a node.
	GetNomadAddr(node Node) string

	// Close releases any resources held by the driver.
	Close() error
}

// ActionContext provides context for action execution.
type ActionContext struct {
	Driver  Driver
	Cluster *Cluster
	State   map[string]any // For storing rollback state
}

// NewActionContext creates a new action context.
func NewActionContext(driver Driver, cluster *Cluster) *ActionContext {
	return &ActionContext{
		Driver:  driver,
		Cluster: cluster,
		State:   make(map[string]any),
	}
}

// AssertContext provides context for assertion checks.
type AssertContext struct {
	Driver  Driver
	Cluster *Cluster
}

// NewAssertContext creates a new assertion context.
func NewAssertContext(driver Driver, cluster *Cluster) *AssertContext {
	return &AssertContext{
		Driver:  driver,
		Cluster: cluster,
	}
}
