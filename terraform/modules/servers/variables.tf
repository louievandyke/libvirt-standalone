variable "stack_name" {
  description = "Prefix for all resources"
  type        = string
}

variable "server_count" {
  description = "Number of server instances"
  type        = number
  default     = 3
}

variable "instance_type" {
  description = "EC2 instance type"
  type        = string
  default     = "t3.medium"
}

variable "ami_id" {
  description = "AMI ID for server instances"
  type        = string
}

variable "subnet_ids" {
  description = "List of subnet IDs"
  type        = list(string)
}

variable "security_group_ids" {
  description = "List of security group IDs"
  type        = list(string)
}

variable "iam_instance_profile" {
  description = "IAM instance profile name"
  type        = string
}

variable "ssh_key_name" {
  description = "EC2 key pair name"
  type        = string
}

variable "root_volume_size" {
  description = "Root EBS volume size in GB"
  type        = number
  default     = 50
}

variable "consul_version" {
  description = "Consul version"
  type        = string
  default     = "1.18.1"
}

variable "vault_version" {
  description = "Vault version"
  type        = string
  default     = "1.18.0"
}

variable "nomad_version" {
  description = "Nomad version"
  type        = string
  default     = "1.9.0"
}

variable "ansible_user" {
  description = "Username for Ansible SSH connections"
  type        = string
  default     = "ubuntu"
}

variable "tags" {
  description = "Additional tags for all resources"
  type        = map(string)
  default     = {}
}
