# Libvirt Standalone

AWS lab infrastructure for developing and testing the [`nomad-driver-virt`][] task driver. This project provides a scalable HashiStack deployment with:

- **Nomad Server Cluster:** 1, 3, or 5 node HA cluster
- **Nomad Clients:** ASG-based horizontal scaling
- **Consul:** Service discovery and auto-join
- **Vault:** Secrets management
- **ALB:** Load balancer for UI access with auto IP allowlist

## Prerequisites

- [Terraform][] >= 1.0
- [AWS CLI][] configured with credentials
- An AWS account

## Quick Start

### 1. Configure Variables

```bash
cd terraform
cp terraform.tfvars.example terraform.tfvars
```

Edit `terraform.tfvars`:
```hcl
stack_owner = "your-name"
stack_name  = "libvirt-test"
region      = "us-west-1"

# Get latest Ubuntu 22.04 AMI:
# aws ec2 describe-images --owners 099720109477 \
#   --filters "Name=name,Values=ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*" \
#   --query 'sort_by(Images, &CreationDate)[-1].ImageId' --region us-west-1
server_ami_id = "ami-xxxxxxxxx"
client_ami_id = "ami-xxxxxxxxx"

# Server cluster size: 1 (dev), 3 (HA), 5 (high availability)
server_count = 1

# Client instance type (see "Instance Types" section below)
client_instance_type = "t3.medium"
client_desired_count = 1
```

### 2. Deploy

```bash
cd terraform
terraform init
terraform apply
```

### 3. Access the Cluster

Terraform outputs UI URLs via ALB:
```bash
terraform output nomad_ui     # http://<alb-dns>:4646
terraform output consul_ui    # http://<alb-dns>:8500
terraform output vault_ui     # http://<alb-dns>:8200
```

SSH to servers:
```bash
terraform output ssh_info
ssh -i keys/<stack-name>.pem ubuntu@<server-ip>
```

## Instance Types

The virt driver requires **bare metal instances** for KVM acceleration. Use cheap instances for infrastructure testing, metal for VM workloads.

| Type | Cost/hr | Use Case |
|------|---------|----------|
| `t3.medium` | ~$0.04 | Infrastructure testing (Docker, exec2) - **NO KVM** |
| `t3.large` | ~$0.08 | Infrastructure testing (more RAM) - **NO KVM** |
| `c5.metal` | ~$4.08 | VM testing with virt driver - **HAS KVM** |
| `i3.metal` | ~$4.99 | VM testing + NVMe storage - **HAS KVM** |

Toggle in `terraform.tfvars`:
```hcl
# Cheap infrastructure testing
client_instance_type = "t3.medium"

# Full VM testing (when ready)
client_instance_type = "i3.metal"
```

## Scaling Clients

```bash
# Via Terraform output helper
terraform output scale_clients_command

# Direct AWS CLI
aws autoscaling set-desired-capacity \
    --auto-scaling-group-name <stack-name>-clients \
    --desired-capacity 3
```

## Upgrades

Update versions in `ansible/group_vars/all.yaml`:
```yaml
consul_version: "1.19.0"
vault_version: "1.19.0"
nomad_version: "1.10.0"
```

Run rolling upgrade:
```bash
cd ansible
ansible-playbook -i inventory/aws_ec2.yaml playbooks/upgrade.yaml
```

The upgrade playbook:
- Upgrades servers one at a time (no draining needed)
- Drains clients before upgrading, re-enables after

## Project Structure

```
.
├── terraform/              # Infrastructure as Code
│   ├── main.tf            # Root module
│   ├── variables.tf       # Configurable variables
│   ├── outputs.tf         # Stack outputs
│   └── modules/
│       ├── network/       # VPC, subnets, security groups
│       ├── iam/           # IAM roles and policies
│       ├── servers/       # Nomad server instances
│       ├── clients/       # Client ASG
│       ├── alb/           # Application Load Balancer
│       └── router/        # Optional bastion
│
├── ansible/               # Configuration management
│   ├── playbooks/
│   │   ├── site.yaml      # Full configuration
│   │   ├── upgrade.yaml   # Rolling upgrades
│   │   ├── servers.yaml
│   │   └── clients.yaml
│   ├── roles/
│   │   ├── common/        # Base packages
│   │   ├── hashicorp_repo/# HashiCorp apt repo
│   │   ├── consul/        # Consul server/client
│   │   ├── vault/         # Vault (servers only)
│   │   ├── nomad/         # Nomad server/client
│   │   ├── nomad_plugins/ # virt + exec2 drivers
│   │   ├── docker/        # Docker CE
│   │   └── libvirt/       # libvirt/QEMU
│   ├── inventory/
│   └── group_vars/
│
├── packer/                # AMI builders
├── scripts/               # Helper scripts
└── jobs/                  # Sample Nomad jobs
```

## Running VM Workloads

> **Note:** Requires metal instance type (`i3.metal` or `c5.metal`)

1. Download a cloud image to the client:
```bash
ssh -i keys/<key>.pem ubuntu@<client-ip>
sudo curl -L -o /var/local/statics/images/focal.img \
    https://cloud-images.ubuntu.com/focal/current/focal-server-cloudimg-amd64.img
```

2. Run a VM job:
```hcl
job "test-vm" {
  datacenters = ["dc1"]
  type = "service"

  group "virt-group" {
    task "virt-task" {
      driver = "nomad-driver-virt"

      config {
        image                 = "/var/local/statics/images/focal.img"
        primary_disk_size     = 10000
        use_thin_copy         = true
        default_user_password = "password"
        cmds                  = ["python3", "-m", "http.server", "8000"]

        network_interface {
          bridge {
            name = "virbr0"
          }
        }
      }

      resources {
        cores  = 2
        memory = 4000
      }
    }
  }
}
```

## Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                           AWS VPC                                │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│  ┌─────────────────────────────────────────────────────────┐    │
│  │                    ALB (UI Access)                       │    │
│  │         :4646 (Nomad) :8500 (Consul) :8200 (Vault)      │    │
│  └─────────────────────────────────────────────────────────┘    │
│                              │                                   │
│  ┌───────────────────────────┼─────────────────────────────┐    │
│  │                           ▼                              │    │
│  │  ┌─────────────────┐  ┌─────────────────────────────┐   │    │
│  │  │  Nomad Servers  │  │     Nomad Clients (ASG)      │   │    │
│  │  │  (1/3/5 nodes)  │  │                              │   │    │
│  │  │                 │  │  ┌───────┐ ┌───────┐        │   │    │
│  │  │  • Consul       │◄─┼─►│Client │ │Client │ ...    │   │    │
│  │  │  • Vault        │  │  │       │ │       │        │   │    │
│  │  │  • Nomad        │  │  │libvirt│ │libvirt│        │   │    │
│  │  │                 │  │  │docker │ │docker │        │   │    │
│  │  └─────────────────┘  │  └───────┘ └───────┘        │   │    │
│  │                       └─────────────────────────────┘   │    │
│  └─────────────────────────────────────────────────────────┘    │
│                                                                  │
│  IP Allowlist: Auto-detected from your current IP                │
└─────────────────────────────────────────────────────────────────┘
```

## Destroying

```bash
cd terraform
terraform destroy
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
[AWS CLI]: https://aws.amazon.com/cli/
[Nomad Documentation]: https://developer.hashicorp.com/nomad/docs
[Consul Documentation]: https://developer.hashicorp.com/consul/docs
