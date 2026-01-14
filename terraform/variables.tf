# =============================================================================
# GENERAL CONFIGURATION
# =============================================================================

variable "stack_name" {
  description = "Prefix for all resources"
  type        = string
  default     = "libvirt"
}

variable "stack_owner" {
  description = "Owner name for resource tagging"
  type        = string
}

variable "region" {
  description = "AWS region for deployment"
  type        = string
  default     = "us-west-1"
}

variable "availability_zones" {
  description = "List of AZs for resource distribution"
  type        = list(string)
  default     = ["us-west-1a", "us-west-1b"]
}

# =============================================================================
# AMI CONFIGURATION
# =============================================================================

variable "server_ami_id" {
  description = "AMI ID for server instances"
  type        = string
}

variable "client_ami_id" {
  description = "AMI ID for client instances"
  type        = string
}

variable "router_ami_id" {
  description = "AMI ID for router instance (defaults to server_ami_id if empty)"
  type        = string
  default     = ""
}

# =============================================================================
# SERVER CONFIGURATION
# =============================================================================

variable "server_count" {
  description = "Number of Nomad server nodes (1, 3, or 5 recommended for Raft consensus)"
  type        = number
  default     = 3

  validation {
    condition     = contains([1, 3, 5], var.server_count)
    error_message = "Server count must be 1, 3, or 5 for proper Raft consensus."
  }
}

variable "server_instance_type" {
  description = "EC2 instance type for server nodes"
  type        = string
  default     = "t3.medium"
}

variable "server_root_volume_size" {
  description = "Root EBS volume size in GB for servers"
  type        = number
  default     = 50
}

# =============================================================================
# CLIENT CONFIGURATION (ASG)
# =============================================================================

variable "client_instance_type" {
  description = "EC2 instance type for Nomad client nodes"
  type        = string
  default     = "i3.metal"
}

variable "client_min_count" {
  description = "Minimum number of client instances in ASG"
  type        = number
  default     = 1
}

variable "client_max_count" {
  description = "Maximum number of client instances in ASG"
  type        = number
  default     = 5
}

variable "client_desired_count" {
  description = "Desired number of client instances in ASG"
  type        = number
  default     = 1
}

variable "client_root_volume_size" {
  description = "Root EBS volume size in GB for clients"
  type        = number
  default     = 100
}

variable "client_node_class" {
  description = "Nomad client node class for job targeting"
  type        = string
  default     = "libvirt"
}

# =============================================================================
# ROUTER CONFIGURATION
# =============================================================================

variable "enable_router" {
  description = "Whether to create a router/bastion instance"
  type        = bool
  default     = true
}

variable "router_instance_type" {
  description = "EC2 instance type for router"
  type        = string
  default     = "t3.small"
}

# =============================================================================
# NETWORK CONFIGURATION
# =============================================================================

variable "create_vpc" {
  description = "Whether to create a new VPC or use default"
  type        = bool
  default     = false
}

variable "vpc_cidr" {
  description = "CIDR block for VPC (only used if create_vpc is true)"
  type        = string
  default     = "10.0.0.0/16"
}

variable "allowlist_ip" {
  description = "CIDR blocks allowed to access the cluster"
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

# =============================================================================
# SSH CONFIGURATION
# =============================================================================

variable "ssh_key_name" {
  description = "Existing EC2 key pair name for SSH access (leave empty to generate)"
  type        = string
  default     = ""
}

# =============================================================================
# HASHICORP VERSIONS
# =============================================================================

variable "consul_version" {
  description = "Consul version to install"
  type        = string
  default     = "1.18.1"
}

variable "vault_version" {
  description = "Vault version to install"
  type        = string
  default     = "1.18.0"
}

variable "nomad_version" {
  description = "Nomad version to install"
  type        = string
  default     = "1.9.0"
}

variable "nomad_driver_virt_version" {
  description = "Nomad virt driver version"
  type        = string
  default     = "0.0.1-beta.1"
}

variable "nomad_driver_exec2_version" {
  description = "Nomad exec2 driver version"
  type        = string
  default     = "0.1.0-beta.2"
}

# =============================================================================
# ANSIBLE USER
# =============================================================================

variable "ansible_user" {
  description = "Username for Ansible SSH connections"
  type        = string
  default     = "ubuntu"
}

# =============================================================================
# TAGGING
# =============================================================================

variable "tags" {
  description = "Additional tags to apply to all resources"
  type        = map(string)
  default     = {}
}
