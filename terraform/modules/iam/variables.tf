variable "stack_name" {
  description = "Prefix for all resources"
  type        = string
}

variable "tags" {
  description = "Additional tags for all resources"
  type        = map(string)
  default     = {}
}
