# Security group for ALB
resource "aws_security_group" "alb" {
  name        = "${var.stack_name}-alb"
  description = "Security group for ALB"
  vpc_id      = var.vpc_id

  # Nomad UI
  ingress {
    from_port   = 4646
    to_port     = 4646
    protocol    = "tcp"
    cidr_blocks = var.allowlist_ip
    description = "Nomad UI"
  }

  # Consul UI
  ingress {
    from_port   = 8500
    to_port     = 8500
    protocol    = "tcp"
    cidr_blocks = var.allowlist_ip
    description = "Consul UI"
  }

  # Vault UI
  ingress {
    from_port   = 8200
    to_port     = 8200
    protocol    = "tcp"
    cidr_blocks = var.allowlist_ip
    description = "Vault UI"
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow all outbound"
  }

  tags = merge(var.tags, {
    Name = "${var.stack_name}-alb-sg"
  })
}

# Application Load Balancer
resource "aws_lb" "main" {
  name               = "${var.stack_name}-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb.id]
  subnets            = var.subnet_ids

  tags = merge(var.tags, {
    Name = "${var.stack_name}-alb"
  })
}

# Target Group for Nomad
resource "aws_lb_target_group" "nomad" {
  name     = "${var.stack_name}-nomad"
  port     = 4646
  protocol = "HTTP"
  vpc_id   = var.vpc_id

  health_check {
    enabled             = true
    healthy_threshold   = 2
    unhealthy_threshold = 2
    timeout             = 5
    interval            = 30
    path                = "/v1/status/leader"
    matcher             = "200"
  }

  tags = merge(var.tags, {
    Name = "${var.stack_name}-nomad-tg"
  })
}

# Target Group for Consul
resource "aws_lb_target_group" "consul" {
  name     = "${var.stack_name}-consul"
  port     = 8500
  protocol = "HTTP"
  vpc_id   = var.vpc_id

  health_check {
    enabled             = true
    healthy_threshold   = 2
    unhealthy_threshold = 2
    timeout             = 5
    interval            = 30
    path                = "/v1/status/leader"
    matcher             = "200"
  }

  tags = merge(var.tags, {
    Name = "${var.stack_name}-consul-tg"
  })
}

# Target Group for Vault
resource "aws_lb_target_group" "vault" {
  name     = "${var.stack_name}-vault"
  port     = 8200
  protocol = "HTTP"
  vpc_id   = var.vpc_id

  health_check {
    enabled             = true
    healthy_threshold   = 2
    unhealthy_threshold = 2
    timeout             = 5
    interval            = 30
    path                = "/v1/sys/health"
    matcher             = "200,429,472,473,501,503" # Vault returns various codes depending on state
  }

  tags = merge(var.tags, {
    Name = "${var.stack_name}-vault-tg"
  })
}

# Listener for Nomad
resource "aws_lb_listener" "nomad" {
  load_balancer_arn = aws_lb.main.arn
  port              = 4646
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.nomad.arn
  }
}

# Listener for Consul
resource "aws_lb_listener" "consul" {
  load_balancer_arn = aws_lb.main.arn
  port              = 8500
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.consul.arn
  }
}

# Listener for Vault
resource "aws_lb_listener" "vault" {
  load_balancer_arn = aws_lb.main.arn
  port              = 8200
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.vault.arn
  }
}

# Attach server instances to Nomad target group
resource "aws_lb_target_group_attachment" "nomad" {
  count            = length(var.server_instance_ids)
  target_group_arn = aws_lb_target_group.nomad.arn
  target_id        = var.server_instance_ids[count.index]
  port             = 4646
}

# Attach server instances to Consul target group
resource "aws_lb_target_group_attachment" "consul" {
  count            = length(var.server_instance_ids)
  target_group_arn = aws_lb_target_group.consul.arn
  target_id        = var.server_instance_ids[count.index]
  port             = 8500
}

# Attach server instances to Vault target group
resource "aws_lb_target_group_attachment" "vault" {
  count            = length(var.server_instance_ids)
  target_group_arn = aws_lb_target_group.vault.arn
  target_id        = var.server_instance_ids[count.index]
  port             = 8200
}
