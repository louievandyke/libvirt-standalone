# Chaos Lab

A Go CLI tool for chaos testing Nomad/Consul/Vault clusters.

## Quick Start

```bash
# Build
make build

# Configure
cp chaos.example.yaml chaos.yaml
# Edit chaos.yaml with your terraform path and SSH key

# Verify cluster discovery
./bin/chaos assert nomad-api-healthy -v

# Run a scenario
./bin/chaos run raft/leader-failover
```

## Commands

```bash
# Inject faults
chaos inject kill-leader                    # Kill the Nomad leader
chaos inject kill-leader --arg signal=KILL  # Kill with SIGKILL
chaos inject partition --arg source=server-0 --arg target=server-1

# Validate cluster state
chaos assert nomad-api-healthy              # Check API quorum
chaos assert leader-elected --within 15s   # Wait for leader

# Rollback last action
chaos heal

# Run scenarios
chaos run raft/leader-failover
chaos run raft/leader-failover --json -o report.json

# View reports
chaos report report.json --format markdown
```

## Configuration

Create `chaos.yaml`:

```yaml
cluster:
  name: "my-cluster"
discovery:
  method: "terraform"
  terraform:
    working_dir: "../terraform"
ssh:
  user: "ubuntu"
  key_path: "../terraform/keys/my-key.pem"
```

## Scenarios

Scenarios are YAML files defining test sequences:

```yaml
name: leader-failover
description: Test Nomad cluster recovery after leader failure
timeout: 2m

steps:
  - name: Verify cluster healthy
    assert: nomad-api-healthy

  - name: Kill the leader
    action: kill-leader

  - name: Wait for election
    wait: 3s

  - name: Verify new leader
    assert: leader-elected
    args:
      within: 15s
```

## Available Actions

| Action | Description | Args |
|--------|-------------|------|
| `kill-leader` | Kill Nomad leader process | `signal`: TERM or KILL |
| `partition` | Network partition between nodes | `source`, `target`, `bidirectional` |

## Available Assertions

| Assertion | Description | Args |
|-----------|-------------|------|
| `leader-elected` | Verify a leader exists | `within`: timeout duration |
| `nomad-api-healthy` | Check API quorum | `min_healthy`: required count |
