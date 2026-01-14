variable "stack_name" {
  description = "Prefix for all resources"
  type        = string
}

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

variable "availability_zones" {
  description = "List of availability zones"
  type        = list(string)
}

variable "allowlist_ip" {
  description = "CIDR blocks allowed to access the cluster"
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

variable "tags" {
  description = "Additional tags for all resources"
  type        = map(string)
  default     = {}
}
