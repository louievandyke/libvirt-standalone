output "instance_id" {
  description = "Router instance ID"
  value       = var.enable ? aws_instance.router[0].id : null
}

output "private_ip" {
  description = "Router private IP"
  value       = var.enable ? aws_instance.router[0].private_ip : null
}

output "public_ip" {
  description = "Router public IP"
  value       = var.enable ? aws_instance.router[0].public_ip : null
}
