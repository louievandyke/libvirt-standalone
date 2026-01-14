output "server_instance_profile_name" {
  description = "Instance profile name for servers"
  value       = aws_iam_instance_profile.servers.name
}

output "client_instance_profile_name" {
  description = "Instance profile name for clients"
  value       = aws_iam_instance_profile.clients.name
}

output "server_iam_role_arn" {
  description = "IAM role ARN for servers"
  value       = aws_iam_role.servers.arn
}

output "client_iam_role_arn" {
  description = "IAM role ARN for clients"
  value       = aws_iam_role.clients.arn
}
