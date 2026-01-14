data "aws_region" "current" {}

# Launch template for ASG
resource "aws_launch_template" "clients" {
  name_prefix   = "${var.stack_name}-client-"
  image_id      = var.ami_id
  instance_type = var.instance_type
  key_name      = var.ssh_key_name

  iam_instance_profile {
    name = var.iam_instance_profile_name
  }

  vpc_security_group_ids = var.security_group_ids

  block_device_mappings {
    device_name = "/dev/sda1"

    ebs {
      volume_size           = var.root_volume_size
      volume_type           = "gp3"
      delete_on_termination = true
    }
  }

  user_data = base64encode(templatefile("${path.module}/templates/user-data.sh.tpl", {
    stack_name                 = var.stack_name
    consul_version             = var.consul_version
    nomad_version              = var.nomad_version
    nomad_driver_virt_version  = var.nomad_driver_virt_version
    nomad_driver_exec2_version = var.nomad_driver_exec2_version
    node_class                 = var.node_class
  }))

  tag_specifications {
    resource_type = "instance"

    tags = merge(var.tags, {
      Name           = "${var.stack_name}-client"
      Role           = "client"
      ConsulAutoJoin = var.stack_name
      AnsibleGroup   = "clients"
      AnsibleUser    = var.ansible_user
      NodeClass      = var.node_class
    })
  }

  tag_specifications {
    resource_type = "volume"

    tags = merge(var.tags, {
      Name = "${var.stack_name}-client-volume"
    })
  }

  tags = merge(var.tags, {
    Name = "${var.stack_name}-client-lt"
  })

  lifecycle {
    create_before_destroy = true
  }
}

# Auto Scaling Group
resource "aws_autoscaling_group" "clients" {
  name                = "${var.stack_name}-clients"
  vpc_zone_identifier = var.subnet_ids
  min_size            = var.min_size
  max_size            = var.max_size
  desired_capacity    = var.desired_capacity

  launch_template {
    id      = aws_launch_template.clients.id
    version = "$Latest"
  }

  health_check_type         = "EC2"
  health_check_grace_period = 300

  # Wait for instances to be healthy
  wait_for_capacity_timeout = "10m"

  tag {
    key                 = "Name"
    value               = "${var.stack_name}-client"
    propagate_at_launch = false
  }

  tag {
    key                 = "ConsulAutoJoin"
    value               = var.stack_name
    propagate_at_launch = false
  }

  dynamic "tag" {
    for_each = var.tags
    content {
      key                 = tag.key
      value               = tag.value
      propagate_at_launch = false
    }
  }

  lifecycle {
    create_before_destroy = true
  }
}
