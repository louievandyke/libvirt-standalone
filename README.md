# Libvirt Standalone

AWS lab infrastructure for developing and testing the [`nomad-driver-virt`][] task driver. This project provides a scalable HashiStack deployment with:

- **Nomad Server Cluster:** 1, 3, or 5 node HA cluster
- **Nomad Clients:** ASG-based horizontal scaling (i3.metal for libvirt)
- **Consul:** Service discovery and auto-join
- **Vault:** Secrets management
- **Configuration:** Fully Ansible-managed

## Prerequisites

- [Terraform][] >= 1.0
- [Ansible][] >= 2.12
- [AWS CLI][] configured with credentials
- An AWS account (resources have non-trivial costs, especially i3.metal instances)

## Quick Start

### 1. Configure Variables

```bash
cd terraform
cp terraform.tfvars.example terraform.tfvars
# Edit terraform.tfvars with your settings
```

Key variables to configure:
- `stack_owner` - Your name for resource tagging
- `server_ami_id` / `client_ami_id` - Ubuntu 22.04 AMI IDs
- `server_count` - Number of servers (1, 3, or 5)
- `client_desired_count` - Initial number of clients

### 2. Deploy

```bash
./scripts/deploy.sh
```

Or step-by-step:
```bash
cd terraform
terraform init
terraform apply

cd ../ansible
ansible-galaxy collection install -r requirements.yaml
ansible-playbook playbooks/site.yaml
```

### 3. Access the Cluster

After deployment, Terraform outputs connection information:
```bash
cd terraform
terraform output ssh_info
terraform output nomad_ui
```

## Project Structure

```
.
├── terraform/              # Infrastructure as Code
│   ├── main.tf            # Root module
│   ├── variables.tf       # Configurable variables
│   ├── outputs.tf         # Stack outputs
│   └── modules/           # Terraform modules
│       ├── network/       # VPC, subnets, security groups
│       ├── iam/           # IAM roles and policies
│       ├── servers/       # Nomad server instances
│       ├── clients/       # Client ASG
│       └── router/        # Optional bastion
│
├── ansible/               # Configuration management
│   ├── playbooks/         # Playbooks
│   ├── roles/             # Ansible roles
│   ├── inventory/         # Dynamic inventory
│   └── group_vars/        # Group variables
│
├── packer/                # AMI builders
├── scripts/               # Helper scripts
├── jobs/                  # Sample Nomad jobs
└── README.md
```

## Scaling Clients

Scale the client ASG:
```bash
./scripts/scale-clients.sh 3  # Scale to 3 clients
./scripts/scale-clients.sh 1  # Scale down to 1
```

Or directly via AWS CLI:
```bash
aws autoscaling set-desired-capacity \
    --auto-scaling-group-name libvirt-clients \
    --desired-capacity 3
```

## Configuration Options

### Server Cluster Sizes

| Count | Use Case |
|-------|----------|
| 1 | Development/testing |
| 3 | Standard HA (recommended) |
| 5 | High availability |

### Instance Types

| Component | Default | Notes |
|-----------|---------|-------|
| Servers | t3.medium | Consul/Vault/Nomad servers |
| Clients | i3.metal | Required for nested virtualization |
| Router | t3.small | Optional bastion host |

## Running VM Workloads

Example Nomad job using the virt driver:
```bash
nomad job run jobs/python-server.hcl
```

See `jobs/` directory for sample job specifications.

## Destroying

```bash
./scripts/destroy.sh
```

Or:
```bash
cd terraform
terraform destroy
```

## Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                        AWS VPC                               │
├─────────────────────────────────────────────────────────────┤
│                                                              │
│  ┌──────────────────────────────────────────────────────┐   │
│  │              Security Groups                          │   │
│  └──────────────────────────────────────────────────────┘   │
│                                                              │
│  ┌─────────────────┐  ┌─────────────────────────────────┐   │
│  │  Nomad Servers  │  │        Nomad Clients (ASG)       │   │
│  │  (1/3/5 nodes)  │  │                                  │   │
│  │                 │  │  ┌───────┐ ┌───────┐ ┌───────┐  │   │
│  │  • Consul       │  │  │Client │ │Client │ │Client │  │   │
│  │  • Vault        │  │  │  1    │ │  2    │ │  N    │  │   │
│  │  • Nomad        │  │  │       │ │       │ │       │  │   │
│  │                 │  │  │libvirt│ │libvirt│ │libvirt│  │   │
│  └─────────────────┘  │  └───────┘ └───────┘ └───────┘  │   │
│                       └─────────────────────────────────┘   │
│                                                              │
│  ┌─────────────────┐                                        │
│  │ Router (opt.)   │                                        │
│  └─────────────────┘                                        │
└─────────────────────────────────────────────────────────────┘
```

## Links

- [nomad-driver-virt][]
- [libvirt][]
- [Nomad Documentation][]
- [Consul Documentation][]

[`nomad-driver-virt`]: https://github.com/hashicorp/nomad-driver-virt
[nomad-driver-virt]: https://github.com/hashicorp/nomad-driver-virt
[libvirt]: https://libvirt.org/
[Terraform]: https://developer.hashicorp.com/terraform/install
[Ansible]: https://docs.ansible.com/ansible/latest/installation_guide/intro_installation.html
[AWS CLI]: https://aws.amazon.com/cli/
[Nomad Documentation]: https://developer.hashicorp.com/nomad/docs
[Consul Documentation]: https://developer.hashicorp.com/consul/docs
