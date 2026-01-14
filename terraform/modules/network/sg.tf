# Security Group for Nomad Servers
resource "aws_security_group" "servers" {
  name        = "${var.stack_name}-servers"
  description = "Security group for Nomad server nodes"
  vpc_id      = local.vpc_id

  tags = merge(var.tags, {
    Name = "${var.stack_name}-servers-sg"
  })
}

# Security Group for Nomad Clients
resource "aws_security_group" "clients" {
  name        = "${var.stack_name}-clients"
  description = "Security group for Nomad client nodes"
  vpc_id      = local.vpc_id

  tags = merge(var.tags, {
    Name = "${var.stack_name}-clients-sg"
  })
}

# Security Group for Router/Bastion
resource "aws_security_group" "router" {
  name        = "${var.stack_name}-router"
  description = "Security group for router/bastion"
  vpc_id      = local.vpc_id

  tags = merge(var.tags, {
    Name = "${var.stack_name}-router-sg"
  })
}

# SSH access from allowlist
resource "aws_security_group_rule" "servers_ssh" {
  type              = "ingress"
  from_port         = 22
  to_port           = 22
  protocol          = "tcp"
  cidr_blocks       = var.allowlist_ip
  security_group_id = aws_security_group.servers.id
  description       = "SSH access"
}

resource "aws_security_group_rule" "clients_ssh" {
  type              = "ingress"
  from_port         = 22
  to_port           = 22
  protocol          = "tcp"
  cidr_blocks       = var.allowlist_ip
  security_group_id = aws_security_group.clients.id
  description       = "SSH access"
}

resource "aws_security_group_rule" "router_ssh" {
  type              = "ingress"
  from_port         = 22
  to_port           = 22
  protocol          = "tcp"
  cidr_blocks       = var.allowlist_ip
  security_group_id = aws_security_group.router.id
  description       = "SSH access"
}

# Nomad HTTP API (4646)
resource "aws_security_group_rule" "servers_nomad_http" {
  type              = "ingress"
  from_port         = 4646
  to_port           = 4646
  protocol          = "tcp"
  cidr_blocks       = var.allowlist_ip
  security_group_id = aws_security_group.servers.id
  description       = "Nomad HTTP API"
}

# Nomad RPC (4647) - server to server
resource "aws_security_group_rule" "servers_nomad_rpc" {
  type                     = "ingress"
  from_port                = 4647
  to_port                  = 4647
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.servers.id
  security_group_id        = aws_security_group.servers.id
  description              = "Nomad RPC server-to-server"
}

# Nomad RPC - clients to servers
resource "aws_security_group_rule" "servers_nomad_rpc_from_clients" {
  type                     = "ingress"
  from_port                = 4647
  to_port                  = 4647
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.clients.id
  security_group_id        = aws_security_group.servers.id
  description              = "Nomad RPC from clients"
}

# Nomad Serf (4648) - server gossip
resource "aws_security_group_rule" "servers_nomad_serf_tcp" {
  type                     = "ingress"
  from_port                = 4648
  to_port                  = 4648
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.servers.id
  security_group_id        = aws_security_group.servers.id
  description              = "Nomad Serf TCP"
}

resource "aws_security_group_rule" "servers_nomad_serf_udp" {
  type                     = "ingress"
  from_port                = 4648
  to_port                  = 4648
  protocol                 = "udp"
  source_security_group_id = aws_security_group.servers.id
  security_group_id        = aws_security_group.servers.id
  description              = "Nomad Serf UDP"
}

# Consul HTTP API (8500)
resource "aws_security_group_rule" "servers_consul_http" {
  type              = "ingress"
  from_port         = 8500
  to_port           = 8500
  protocol          = "tcp"
  cidr_blocks       = var.allowlist_ip
  security_group_id = aws_security_group.servers.id
  description       = "Consul HTTP API"
}

# Consul RPC (8300) - server to server
resource "aws_security_group_rule" "servers_consul_rpc" {
  type                     = "ingress"
  from_port                = 8300
  to_port                  = 8300
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.servers.id
  security_group_id        = aws_security_group.servers.id
  description              = "Consul RPC server-to-server"
}

# Consul RPC - clients to servers
resource "aws_security_group_rule" "servers_consul_rpc_from_clients" {
  type                     = "ingress"
  from_port                = 8300
  to_port                  = 8300
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.clients.id
  security_group_id        = aws_security_group.servers.id
  description              = "Consul RPC from clients"
}

# Consul Serf LAN (8301)
resource "aws_security_group_rule" "servers_consul_serf_lan_tcp" {
  type                     = "ingress"
  from_port                = 8301
  to_port                  = 8301
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.servers.id
  security_group_id        = aws_security_group.servers.id
  description              = "Consul Serf LAN TCP servers"
}

resource "aws_security_group_rule" "servers_consul_serf_lan_tcp_from_clients" {
  type                     = "ingress"
  from_port                = 8301
  to_port                  = 8301
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.clients.id
  security_group_id        = aws_security_group.servers.id
  description              = "Consul Serf LAN TCP from clients"
}

resource "aws_security_group_rule" "servers_consul_serf_lan_udp" {
  type                     = "ingress"
  from_port                = 8301
  to_port                  = 8301
  protocol                 = "udp"
  source_security_group_id = aws_security_group.servers.id
  security_group_id        = aws_security_group.servers.id
  description              = "Consul Serf LAN UDP servers"
}

resource "aws_security_group_rule" "servers_consul_serf_lan_udp_from_clients" {
  type                     = "ingress"
  from_port                = 8301
  to_port                  = 8301
  protocol                 = "udp"
  source_security_group_id = aws_security_group.clients.id
  security_group_id        = aws_security_group.servers.id
  description              = "Consul Serf LAN UDP from clients"
}

# Consul Serf WAN (8302) - server to server only
resource "aws_security_group_rule" "servers_consul_serf_wan_tcp" {
  type                     = "ingress"
  from_port                = 8302
  to_port                  = 8302
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.servers.id
  security_group_id        = aws_security_group.servers.id
  description              = "Consul Serf WAN TCP"
}

resource "aws_security_group_rule" "servers_consul_serf_wan_udp" {
  type                     = "ingress"
  from_port                = 8302
  to_port                  = 8302
  protocol                 = "udp"
  source_security_group_id = aws_security_group.servers.id
  security_group_id        = aws_security_group.servers.id
  description              = "Consul Serf WAN UDP"
}

# Vault HTTP API (8200)
resource "aws_security_group_rule" "servers_vault_http" {
  type              = "ingress"
  from_port         = 8200
  to_port           = 8200
  protocol          = "tcp"
  cidr_blocks       = var.allowlist_ip
  security_group_id = aws_security_group.servers.id
  description       = "Vault HTTP API"
}

# Vault internal from clients
resource "aws_security_group_rule" "servers_vault_from_clients" {
  type                     = "ingress"
  from_port                = 8200
  to_port                  = 8200
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.clients.id
  security_group_id        = aws_security_group.servers.id
  description              = "Vault access from clients"
}

# Client security group rules

# Clients need to talk to servers for Consul
resource "aws_security_group_rule" "clients_consul_serf_lan_tcp" {
  type                     = "ingress"
  from_port                = 8301
  to_port                  = 8301
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.servers.id
  security_group_id        = aws_security_group.clients.id
  description              = "Consul Serf LAN TCP from servers"
}

resource "aws_security_group_rule" "clients_consul_serf_lan_tcp_from_clients" {
  type                     = "ingress"
  from_port                = 8301
  to_port                  = 8301
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.clients.id
  security_group_id        = aws_security_group.clients.id
  description              = "Consul Serf LAN TCP client-to-client"
}

resource "aws_security_group_rule" "clients_consul_serf_lan_udp" {
  type                     = "ingress"
  from_port                = 8301
  to_port                  = 8301
  protocol                 = "udp"
  source_security_group_id = aws_security_group.servers.id
  security_group_id        = aws_security_group.clients.id
  description              = "Consul Serf LAN UDP from servers"
}

resource "aws_security_group_rule" "clients_consul_serf_lan_udp_from_clients" {
  type                     = "ingress"
  from_port                = 8301
  to_port                  = 8301
  protocol                 = "udp"
  source_security_group_id = aws_security_group.clients.id
  security_group_id        = aws_security_group.clients.id
  description              = "Consul Serf LAN UDP client-to-client"
}

# Nomad dynamic ports for workloads (20000-32000)
resource "aws_security_group_rule" "clients_nomad_dynamic" {
  type              = "ingress"
  from_port         = 20000
  to_port           = 32000
  protocol          = "tcp"
  cidr_blocks       = var.allowlist_ip
  security_group_id = aws_security_group.clients.id
  description       = "Nomad dynamic ports for workloads"
}

# Egress rules - allow all outbound
resource "aws_security_group_rule" "servers_egress" {
  type              = "egress"
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.servers.id
  description       = "Allow all outbound"
}

resource "aws_security_group_rule" "clients_egress" {
  type              = "egress"
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.clients.id
  description       = "Allow all outbound"
}

resource "aws_security_group_rule" "router_egress" {
  type              = "egress"
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.router.id
  description       = "Allow all outbound"
}
