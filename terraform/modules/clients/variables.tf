variable "stack_name" {
  description = "Prefix for all resources"
  type        = string
}

variable "instance_type" {
  description = "EC2 instance type"
  type        = string
  default     = "i3.metal"
}

variable "ami_id" {
  description = "AMI ID for client instances"
  type        = string
}

variable "min_size" {
  description = "Minimum number of instances in ASG"
  type        = number
  default     = 1
}

variable "max_size" {
  description = "Maximum number of instances in ASG"
  type        = number
  default     = 5
}

variable "desired_capacity" {
  description = "Desired number of instances in ASG"
  type        = number
  default     = 1
}

variable "subnet_ids" {
  description = "List of subnet IDs"
  type        = list(string)
}

variable "security_group_ids" {
  description = "List of security group IDs"
  type        = list(string)
}

variable "iam_instance_profile_name" {
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
  default     = 100
}

variable "consul_version" {
  description = "Consul version"
  type        = string
  default     = "1.18.1"
}

variable "nomad_version" {
  description = "Nomad version"
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

variable "node_class" {
  description = "Nomad client node class"
  type        = string
  default     = "libvirt"
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
