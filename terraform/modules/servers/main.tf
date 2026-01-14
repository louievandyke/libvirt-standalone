data "aws_region" "current" {}

resource "aws_instance" "servers" {
  count = var.server_count

  ami                    = var.ami_id
  instance_type          = var.instance_type
  subnet_id              = element(var.subnet_ids, count.index % length(var.subnet_ids))
  vpc_security_group_ids = var.security_group_ids
  iam_instance_profile   = var.iam_instance_profile
  key_name               = var.ssh_key_name

  root_block_device {
    volume_size           = var.root_volume_size
    volume_type           = "gp3"
    delete_on_termination = true
  }

  user_data = templatefile("${path.module}/templates/user-data.sh.tpl", {
    server_count   = var.server_count
    stack_name     = var.stack_name
    consul_version = var.consul_version
    vault_version  = var.vault_version
    nomad_version  = var.nomad_version
  })

  tags = merge(var.tags, {
    Name           = "${var.stack_name}-server-${count.index}"
    Role           = "server"
    ConsulAutoJoin = var.stack_name
    AnsibleGroup   = "servers"
    AnsibleUser    = var.ansible_user
  })

  lifecycle {
    ignore_changes = [ami]
  }
}
