provider "aws" {
  region = var.region
}

locals {
  common_tags = merge(var.tags, {
    StackName  = var.stack_name
    StackOwner = var.stack_owner
    ManagedBy  = "terraform"
  })

  router_ami_id = var.router_ami_id != "" ? var.router_ami_id : var.server_ami_id
}

# Generate SSH key pair if not provided
module "keys" {
  source  = "mitchellh/dynamic-keys/aws"
  version = "v2.0.0"

  count = var.ssh_key_name == "" ? 1 : 0
  name  = var.stack_name
  path  = "${path.root}/keys"
}

locals {
  ssh_key_name = var.ssh_key_name != "" ? var.ssh_key_name : module.keys[0].key_name
}

# Network module (VPC, subnets, security groups)
module "network" {
  source = "./modules/network"

  stack_name         = var.stack_name
  create_vpc         = var.create_vpc
  vpc_cidr           = var.vpc_cidr
  availability_zones = var.availability_zones
  allowlist_ip       = var.allowlist_ip
  tags               = local.common_tags
}

# IAM module (roles, policies, instance profiles)
module "iam" {
  source = "./modules/iam"

  stack_name = var.stack_name
  tags       = local.common_tags
}

# Nomad Servers (static EC2 instances)
module "servers" {
  source = "./modules/servers"

  stack_name           = var.stack_name
  server_count         = var.server_count
  instance_type        = var.server_instance_type
  ami_id               = var.server_ami_id
  subnet_ids           = module.network.subnet_ids
  security_group_ids   = [module.network.server_security_group_id]
  iam_instance_profile = module.iam.server_instance_profile_name
  ssh_key_name         = local.ssh_key_name
  root_volume_size     = var.server_root_volume_size
  consul_version       = var.consul_version
  vault_version        = var.vault_version
  nomad_version        = var.nomad_version
  ansible_user         = var.ansible_user
  tags                 = local.common_tags
}

# Nomad Clients (ASG for horizontal scaling)
module "clients" {
  source = "./modules/clients"

  stack_name                 = var.stack_name
  instance_type              = var.client_instance_type
  ami_id                     = var.client_ami_id
  min_size                   = var.client_min_count
  max_size                   = var.client_max_count
  desired_capacity           = var.client_desired_count
  subnet_ids                 = module.network.subnet_ids
  security_group_ids         = [module.network.client_security_group_id]
  iam_instance_profile_name  = module.iam.client_instance_profile_name
  ssh_key_name               = local.ssh_key_name
  root_volume_size           = var.client_root_volume_size
  consul_version             = var.consul_version
  nomad_version              = var.nomad_version
  nomad_driver_virt_version  = var.nomad_driver_virt_version
  nomad_driver_exec2_version = var.nomad_driver_exec2_version
  node_class                 = var.client_node_class
  ansible_user               = var.ansible_user
  tags                       = local.common_tags

  depends_on = [module.servers]
}

# Router/Bastion (optional)
module "router" {
  source = "./modules/router"

  stack_name         = var.stack_name
  enable             = var.enable_router
  instance_type      = var.router_instance_type
  ami_id             = local.router_ami_id
  subnet_id          = module.network.subnet_ids[0]
  security_group_ids = [module.network.router_security_group_id]
  ssh_key_name       = local.ssh_key_name
  ansible_user       = var.ansible_user
  tags               = local.common_tags
}
