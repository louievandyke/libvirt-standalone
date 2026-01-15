variable "stack_name" {
  description = "Prefix for all resources"
  type        = string
}

variable "vpc_id" {
  description = "VPC ID"
  type        = string
}

variable "subnet_ids" {
  description = "List of subnet IDs for ALB"
  type        = list(string)
}

variable "allowlist_ip" {
  description = "CIDR blocks allowed to access the ALB"
  type        = list(string)
}

variable "server_instance_ids" {
  description = "List of server instance IDs to attach to target groups"
  type        = list(string)
}

variable "tags" {
  description = "Additional tags for all resources"
  type        = map(string)
  default     = {}
}
