resource "aws_instance" "router" {
  count = var.enable ? 1 : 0

  ami                    = var.ami_id
  instance_type          = var.instance_type
  subnet_id              = var.subnet_id
  vpc_security_group_ids = var.security_group_ids
  key_name               = var.ssh_key_name

  root_block_device {
    volume_size           = 20
    volume_type           = "gp3"
    delete_on_termination = true
  }

  tags = merge(var.tags, {
    Name         = "${var.stack_name}-router"
    Role         = "router"
    AnsibleGroup = "router"
    AnsibleUser  = var.ansible_user
  })

  lifecycle {
    ignore_changes = [ami]
  }
}
