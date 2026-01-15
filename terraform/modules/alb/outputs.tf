output "alb_dns_name" {
  description = "DNS name of the ALB"
  value       = aws_lb.main.dns_name
}

output "alb_arn" {
  description = "ARN of the ALB"
  value       = aws_lb.main.arn
}

output "alb_security_group_id" {
  description = "Security group ID of the ALB"
  value       = aws_security_group.alb.id
}

output "nomad_url" {
  description = "Nomad UI URL via ALB"
  value       = "http://${aws_lb.main.dns_name}:4646"
}

output "consul_url" {
  description = "Consul UI URL via ALB"
  value       = "http://${aws_lb.main.dns_name}:8500"
}

output "vault_url" {
  description = "Vault UI URL via ALB"
  value       = "http://${aws_lb.main.dns_name}:8200"
}
