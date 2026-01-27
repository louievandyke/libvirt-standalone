// Package config handles loading and validation of chaos tool configuration.
package config

import (
	"fmt"
	"os"
	"path/filepath"

	"gopkg.in/yaml.v3"
)

// Config represents the top-level configuration for the chaos tool.
type Config struct {
	Cluster   ClusterConfig   `yaml:"cluster"`
	Discovery DiscoveryConfig `yaml:"discovery"`
	SSH       SSHConfig       `yaml:"ssh"`
	Nomad     NomadConfig     `yaml:"nomad"`
	Consul    ConsulConfig    `yaml:"consul"`
}

// ClusterConfig identifies the target cluster.
type ClusterConfig struct {
	Name string `yaml:"name"`
}

// DiscoveryConfig configures how nodes are discovered.
type DiscoveryConfig struct {
	Method    string          `yaml:"method"` // "terraform" or "static"
	Terraform TerraformConfig `yaml:"terraform"`
	Static    StaticConfig    `yaml:"static"`
}

// TerraformConfig for terraform-based discovery.
type TerraformConfig struct {
	WorkingDir string `yaml:"working_dir"`
}

// StaticConfig for manually specified nodes.
type StaticConfig struct {
	Servers []string `yaml:"servers"`
	Clients []string `yaml:"clients"`
}

// SSHConfig for SSH connections to nodes.
type SSHConfig struct {
	User           string `yaml:"user"`
	KeyPath        string `yaml:"key_path"`
	Port           int    `yaml:"port"`
	ConnectTimeout int    `yaml:"connect_timeout"` // seconds
}

// NomadConfig for Nomad API connections.
type NomadConfig struct {
	Address   string `yaml:"address"`
	Token     string `yaml:"token"`
	TLSConfig TLS    `yaml:"tls"`
}

// ConsulConfig for Consul API connections.
type ConsulConfig struct {
	Address   string `yaml:"address"`
	Token     string `yaml:"token"`
	TLSConfig TLS    `yaml:"tls"`
}

// TLS configuration for API connections.
type TLS struct {
	CACert     string `yaml:"ca_cert"`
	ClientCert string `yaml:"client_cert"`
	ClientKey  string `yaml:"client_key"`
	Insecure   bool   `yaml:"insecure"`
}

// DefaultConfig returns a configuration with sensible defaults.
func DefaultConfig() *Config {
	return &Config{
		Cluster: ClusterConfig{
			Name: "libvirt-test",
		},
		Discovery: DiscoveryConfig{
			Method: "terraform",
			Terraform: TerraformConfig{
				WorkingDir: "./terraform",
			},
		},
		SSH: SSHConfig{
			User:           "ubuntu",
			KeyPath:        "./terraform/keys/libvirt-test.pem",
			Port:           22,
			ConnectTimeout: 10,
		},
		Nomad: NomadConfig{
			Address: "http://localhost:4646",
		},
		Consul: ConsulConfig{
			Address: "http://localhost:8500",
		},
	}
}

// Load reads configuration from the specified file path.
func Load(path string) (*Config, error) {
	cfg := DefaultConfig()

	data, err := os.ReadFile(path)
	if err != nil {
		return nil, fmt.Errorf("reading config file: %w", err)
	}

	if err := yaml.Unmarshal(data, cfg); err != nil {
		return nil, fmt.Errorf("parsing config file: %w", err)
	}

	if err := cfg.Validate(); err != nil {
		return nil, fmt.Errorf("validating config: %w", err)
	}

	// Resolve relative paths
	cfg.resolvePaths(filepath.Dir(path))

	return cfg, nil
}

// LoadFromDir searches for chaos.yaml in the given directory and parents.
func LoadFromDir(dir string) (*Config, error) {
	configNames := []string{"chaos.yaml", "chaos.yml", ".chaos.yaml", ".chaos.yml"}

	current := dir
	for {
		for _, name := range configNames {
			path := filepath.Join(current, name)
			if _, err := os.Stat(path); err == nil {
				return Load(path)
			}
		}

		parent := filepath.Dir(current)
		if parent == current {
			break
		}
		current = parent
	}

	return nil, fmt.Errorf("no chaos.yaml found in %s or parent directories", dir)
}

// Validate checks the configuration for errors.
func (c *Config) Validate() error {
	if c.Discovery.Method == "" {
		return fmt.Errorf("discovery.method is required")
	}

	switch c.Discovery.Method {
	case "terraform":
		if c.Discovery.Terraform.WorkingDir == "" {
			return fmt.Errorf("discovery.terraform.working_dir is required")
		}
	case "static":
		if len(c.Discovery.Static.Servers) == 0 {
			return fmt.Errorf("discovery.static.servers is required for static discovery")
		}
	default:
		return fmt.Errorf("unknown discovery method: %s", c.Discovery.Method)
	}

	if c.SSH.User == "" {
		return fmt.Errorf("ssh.user is required")
	}
	if c.SSH.KeyPath == "" {
		return fmt.Errorf("ssh.key_path is required")
	}

	return nil
}

// resolvePaths converts relative paths to absolute paths based on config dir.
func (c *Config) resolvePaths(baseDir string) {
	resolve := func(path string) string {
		if path == "" || filepath.IsAbs(path) {
			return path
		}
		return filepath.Join(baseDir, path)
	}

	c.Discovery.Terraform.WorkingDir = resolve(c.Discovery.Terraform.WorkingDir)
	c.SSH.KeyPath = resolve(c.SSH.KeyPath)
	c.Nomad.TLSConfig.CACert = resolve(c.Nomad.TLSConfig.CACert)
	c.Nomad.TLSConfig.ClientCert = resolve(c.Nomad.TLSConfig.ClientCert)
	c.Nomad.TLSConfig.ClientKey = resolve(c.Nomad.TLSConfig.ClientKey)
	c.Consul.TLSConfig.CACert = resolve(c.Consul.TLSConfig.CACert)
	c.Consul.TLSConfig.ClientCert = resolve(c.Consul.TLSConfig.ClientCert)
	c.Consul.TLSConfig.ClientKey = resolve(c.Consul.TLSConfig.ClientKey)
}
