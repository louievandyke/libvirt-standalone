# IAM Role for Servers (Consul auto-join, EC2 describe)
resource "aws_iam_role" "servers" {
  name = "${var.stack_name}-servers"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      }
    ]
  })

  tags = merge(var.tags, {
    Name = "${var.stack_name}-servers-role"
  })
}

# IAM Role for Clients (Consul auto-join, EC2 describe, ASG operations)
resource "aws_iam_role" "clients" {
  name = "${var.stack_name}-clients"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      }
    ]
  })

  tags = merge(var.tags, {
    Name = "${var.stack_name}-clients-role"
  })
}

# Policy for Consul auto-join (EC2 describe)
resource "aws_iam_policy" "consul_auto_join" {
  name        = "${var.stack_name}-consul-auto-join"
  description = "Allow Consul auto-join via EC2 tags"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "ec2:DescribeInstances",
          "ec2:DescribeTags"
        ]
        Resource = "*"
      }
    ]
  })

  tags = var.tags
}

# Policy for ASG operations (for Nomad autoscaler integration)
resource "aws_iam_policy" "asg_operations" {
  name        = "${var.stack_name}-asg-operations"
  description = "Allow ASG operations for Nomad autoscaler"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "autoscaling:DescribeAutoScalingGroups",
          "autoscaling:DescribeAutoScalingInstances",
          "autoscaling:SetDesiredCapacity",
          "autoscaling:TerminateInstanceInAutoScalingGroup",
          "autoscaling:UpdateAutoScalingGroup"
        ]
        Resource = "*"
      }
    ]
  })

  tags = var.tags
}

# SSM policy for remote management
resource "aws_iam_policy" "ssm_access" {
  name        = "${var.stack_name}-ssm-access"
  description = "Allow SSM access for remote management"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "ssm:UpdateInstanceInformation",
          "ssmmessages:CreateControlChannel",
          "ssmmessages:CreateDataChannel",
          "ssmmessages:OpenControlChannel",
          "ssmmessages:OpenDataChannel"
        ]
        Resource = "*"
      }
    ]
  })

  tags = var.tags
}

# Attach policies to server role
resource "aws_iam_role_policy_attachment" "servers_consul_auto_join" {
  role       = aws_iam_role.servers.name
  policy_arn = aws_iam_policy.consul_auto_join.arn
}

resource "aws_iam_role_policy_attachment" "servers_ssm" {
  role       = aws_iam_role.servers.name
  policy_arn = aws_iam_policy.ssm_access.arn
}

# Attach policies to client role
resource "aws_iam_role_policy_attachment" "clients_consul_auto_join" {
  role       = aws_iam_role.clients.name
  policy_arn = aws_iam_policy.consul_auto_join.arn
}

resource "aws_iam_role_policy_attachment" "clients_asg" {
  role       = aws_iam_role.clients.name
  policy_arn = aws_iam_policy.asg_operations.arn
}

resource "aws_iam_role_policy_attachment" "clients_ssm" {
  role       = aws_iam_role.clients.name
  policy_arn = aws_iam_policy.ssm_access.arn
}

# Instance profiles
resource "aws_iam_instance_profile" "servers" {
  name = "${var.stack_name}-servers"
  role = aws_iam_role.servers.name

  tags = merge(var.tags, {
    Name = "${var.stack_name}-servers-profile"
  })
}

resource "aws_iam_instance_profile" "clients" {
  name = "${var.stack_name}-clients"
  role = aws_iam_role.clients.name

  tags = merge(var.tags, {
    Name = "${var.stack_name}-clients-profile"
  })
}
