output "asg_name" {
  description = "Name of the Auto Scaling Group"
  value       = aws_autoscaling_group.clients.name
}

output "asg_arn" {
  description = "ARN of the Auto Scaling Group"
  value       = aws_autoscaling_group.clients.arn
}

output "launch_template_id" {
  description = "ID of the Launch Template"
  value       = aws_launch_template.clients.id
}

output "launch_template_latest_version" {
  description = "Latest version of the Launch Template"
  value       = aws_launch_template.clients.latest_version
}
