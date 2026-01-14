variable "stack_name" {
  description = "Prefix for all resources"
  type        = string
}

variable "enable" {
  description = "Whether to create the router instance"
  type        = bool
  default     = true
}

variable "instance_type" {
  description = "EC2 instance type"
  type        = string
  default     = "t3.small"
}

variable "ami_id" {
  description = "AMI ID for router instance"
  type        = string
}

variable "subnet_id" {
  description = "Subnet ID for the router"
  type        = string
}

variable "security_group_ids" {
  description = "List of security group IDs"
  type        = list(string)
}

variable "ssh_key_name" {
  description = "EC2 key pair name"
  type        = string
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
