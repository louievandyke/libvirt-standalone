package driver

import (
	"bytes"
	"context"
	"fmt"
	"io"
	"net"
	"os"
	"time"

	"golang.org/x/crypto/ssh"
)

// SSHConfig configures SSH connections.
type SSHConfig struct {
	User           string
	KeyPath        string
	Port           int
	ConnectTimeout time.Duration
}

// sshClient implements SSHClient.
type sshClient struct {
	client *ssh.Client
	node   Node
}

// NewSSHClient creates a new SSH client connection to a node.
func NewSSHClient(ctx context.Context, node Node, cfg SSHConfig) (SSHClient, error) {
	keyData, err := os.ReadFile(cfg.KeyPath)
	if err != nil {
		return nil, fmt.Errorf("reading SSH key: %w", err)
	}

	signer, err := ssh.ParsePrivateKey(keyData)
	if err != nil {
		return nil, fmt.Errorf("parsing SSH key: %w", err)
	}

	config := &ssh.ClientConfig{
		User: cfg.User,
		Auth: []ssh.AuthMethod{
			ssh.PublicKeys(signer),
		},
		HostKeyCallback: ssh.InsecureIgnoreHostKey(), // For testing environments
		Timeout:         cfg.ConnectTimeout,
	}

	addr := fmt.Sprintf("%s:%d", node.PublicIP, cfg.Port)

	// Use context for connection timeout
	var conn net.Conn
	dialer := &net.Dialer{Timeout: cfg.ConnectTimeout}

	conn, err = dialer.DialContext(ctx, "tcp", addr)
	if err != nil {
		return nil, fmt.Errorf("connecting to %s: %w", addr, err)
	}

	// Perform SSH handshake
	sshConn, chans, reqs, err := ssh.NewClientConn(conn, addr, config)
	if err != nil {
		conn.Close()
		return nil, fmt.Errorf("SSH handshake with %s: %w", addr, err)
	}

	client := ssh.NewClient(sshConn, chans, reqs)

	return &sshClient{
		client: client,
		node:   node,
	}, nil
}

// Run executes a command and returns output.
func (c *sshClient) Run(ctx context.Context, cmd string) (stdout, stderr string, exitCode int, err error) {
	session, err := c.client.NewSession()
	if err != nil {
		return "", "", -1, fmt.Errorf("creating SSH session: %w", err)
	}
	defer session.Close()

	var stdoutBuf, stderrBuf bytes.Buffer
	session.Stdout = &stdoutBuf
	session.Stderr = &stderrBuf

	// Handle context cancellation
	done := make(chan error, 1)
	go func() {
		done <- session.Run(cmd)
	}()

	select {
	case <-ctx.Done():
		session.Signal(ssh.SIGKILL)
		return "", "", -1, ctx.Err()
	case err := <-done:
		exitCode = 0
		if err != nil {
			if exitErr, ok := err.(*ssh.ExitError); ok {
				exitCode = exitErr.ExitStatus()
			} else {
				return stdoutBuf.String(), stderrBuf.String(), -1, err
			}
		}
		return stdoutBuf.String(), stderrBuf.String(), exitCode, nil
	}
}

// RunWithSudo executes a command with sudo.
func (c *sshClient) RunWithSudo(ctx context.Context, cmd string) (stdout, stderr string, exitCode int, err error) {
	sudoCmd := fmt.Sprintf("sudo -n %s", cmd)
	return c.Run(ctx, sudoCmd)
}

// Stream executes a command and streams output.
func (c *sshClient) Stream(ctx context.Context, cmd string, stdout, stderr io.Writer) (exitCode int, err error) {
	session, err := c.client.NewSession()
	if err != nil {
		return -1, fmt.Errorf("creating SSH session: %w", err)
	}
	defer session.Close()

	session.Stdout = stdout
	session.Stderr = stderr

	done := make(chan error, 1)
	go func() {
		done <- session.Run(cmd)
	}()

	select {
	case <-ctx.Done():
		session.Signal(ssh.SIGKILL)
		return -1, ctx.Err()
	case err := <-done:
		exitCode = 0
		if err != nil {
			if exitErr, ok := err.(*ssh.ExitError); ok {
				exitCode = exitErr.ExitStatus()
			} else {
				return -1, err
			}
		}
		return exitCode, nil
	}
}

// Close closes the SSH connection.
func (c *sshClient) Close() error {
	return c.client.Close()
}
