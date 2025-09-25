locals {
  stack_region  = "us-west-1"
  stack_name    = "libvirt-no"
  stack_owner   = "lvandyke"
  ansible_user  = "lvandyke"
  #ec2_ami_id    = "ami-01353cf5c7f703f8d"
  #ec2_ami_id    =  "ami-08296be07d7a9c86c"
  #ec2_ami_id    = "ami-0fb4a35c6f84c0196"
  #ec2_ami_id    = "ami-09f8fd338f94c8403"  #Dan's
  #ec2_ami_id    =  "ami-026c3b5318f22a934"
  #ec2_ami_id    =  "ami-06f2bb5fac93eb06c"
  #ec2_ami_id    =  "ami-06f36cfa34cacd829"
  #ec2_ami_id    =  "ami-06dbfb10fd4a68cd8"
  ec2_ami_id    =  "ami-0b5a464cf5f40b28a"
  ec2_user_data = <<EOH
#cloud-config
---
users:
  - default
  - name: lvandyke
    sudo: ALL=(ALL) NOPASSWD:ALL
    shell: /bin/bash
    ssh_authorized_keys:
      - ssh-rsa 
        AAAAB3NzaC1yc2EAAAADAQABAAABgQCkQ8ZpeWPN5DCAqmwRXraU674GkD++WQnEoZ8PppbsgryIGU71F7iEjnxMfsn0jAhB8RsG3BEQ+c8tOM5VbH5hr0pdOqOyPq0ZmMAFMe6Kg2AmItLfGDDbZMtpJ+qUs+TTZaLahz3+xJRA2/XBEQhmeAEOAOV5ZeRFFbA3cHGx3ki0cSkreA8YWjbDgy7wqM4jHFrC12+PDtFNUOKWu+owiyEzgKL9RnNPok8wH8TWzVLuUxlP9GHW8vfRoGjwTMKsSlPM6U4OdT1TNQo8Cj6Z58HwyhruDdEI/kqOp+GxxdxT2fGITxTPSY1sbe7uN0J/68pslzbkHgki9fmeymhwPcEBlSJWFUnXD3siD6n5yP63ptkrUMmGpEWRS4aorFYTRZfOXAnZSQMMlffgmVyYsSjusv8DdP4dOTqomsX6aOI3QQBCOb9wm9ShsFLL5QOOoHQ9Zx0UZcFQTiMWBbWclrF7uPc7D3wZf6Mzy5xCLLIwFFAIJ32ihG5hmnRsQ20= lvandyke@lvandyke-C1K4W7H3FG
EOH
}

provider "aws" {
  region = local.stack_region
}

module "keys" {
  source  = "mitchellh/dynamic-keys/aws"
  version = "v2.0.0"

  name = local.stack_name
  path = "${path.root}/keys"
}

module "network" {
  source     = "../../shared/terraform/aws-network"
  stack_name = local.stack_name 
}

module "libvirt_compute" {
  source = "../../shared/terraform/aws-compute"

  ami_id             = local.ec2_ami_id
  ansible_group_name = "libvirt"
  component_name     = "libvirt"
  instance_type      = "i3.metal"
  security_group_ids = [module.network.security_group_id]
  ssh_key_name       = module.keys.key_name
  stack_name         = local.stack_name
  subnet_id          = module.network.subnet_id
  user_data          = local.ec2_user_data
}

module "libvirt_router" {
  source = "../../shared/terraform/aws-compute"

  ami_id             = local.ec2_ami_id
  ansible_group_name = "router"
  component_name     = "router"
  instance_type      = "t3.small"
  security_group_ids = [module.network.security_group_id]
  ssh_key_name       = module.keys.key_name
  stack_name         = local.stack_name
  subnet_id          = module.network.subnet_id
  user_data          = local.ec2_user_data
}

output "ssh_details" {
  value = <<EOH
Libvirt instance: ${module.libvirt_compute.instance_public_ips[0]}
Router instance:  ${module.libvirt_router.instance_public_ips[0]}
EOH
}
