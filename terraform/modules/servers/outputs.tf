output "instance_ids" {
  description = "List of server instance IDs"
  value       = aws_instance.servers[*].id
}

output "private_ips" {
  description = "List of server private IPs"
  value       = aws_instance.servers[*].private_ip
}

output "public_ips" {
  description = "List of server public IPs"
  value       = aws_instance.servers[*].public_ip
}

output "server_count" {
  description = "Number of server instances"
  value       = var.server_count
}
