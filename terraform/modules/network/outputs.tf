output "vpc_id" {
  description = "VPC ID"
  value       = local.vpc_id
}

output "subnet_ids" {
  description = "List of subnet IDs"
  value       = local.subnet_ids
}

output "server_security_group_id" {
  description = "Security group ID for servers"
  value       = aws_security_group.servers.id
}

output "client_security_group_id" {
  description = "Security group ID for clients"
  value       = aws_security_group.clients.id
}

output "router_security_group_id" {
  description = "Security group ID for router"
  value       = aws_security_group.router.id
}
