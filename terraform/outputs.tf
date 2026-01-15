# =============================================================================
# CLUSTER INFO
# =============================================================================

output "cluster_info" {
  description = "Cluster configuration summary"
  value = {
    stack_name   = var.stack_name
    region       = var.region
    server_count = var.server_count
    client_config = {
      min     = var.client_min_count
      max     = var.client_max_count
      desired = var.client_desired_count
    }
  }
}

output "your_ip" {
  description = "Your detected IP address (used for allowlist)"
  value       = "${module.my_ip_address.stdout}/32"
  sensitive   = true
}

# =============================================================================
# SERVER OUTPUTS
# =============================================================================

output "server_public_ips" {
  description = "Public IP addresses of Nomad servers"
  value       = module.servers.public_ips
}

output "server_private_ips" {
  description = "Private IP addresses of Nomad servers"
  value       = module.servers.private_ips
}

# =============================================================================
# CLIENT OUTPUTS
# =============================================================================

output "client_asg_name" {
  description = "Name of the client Auto Scaling Group"
  value       = module.clients.asg_name
}

output "client_asg_arn" {
  description = "ARN of the client Auto Scaling Group"
  value       = module.clients.asg_arn
}

# =============================================================================
# ROUTER OUTPUTS
# =============================================================================

output "router_public_ip" {
  description = "Public IP address of the router instance"
  value       = module.router.public_ip
}

# =============================================================================
# SSH CONNECTION INFO
# =============================================================================

output "ssh_info" {
  description = "SSH connection information"
  value       = <<-EOT

    ============================================
    SSH Connection Information
    ============================================

    Servers:
    %{for i, ip in module.servers.public_ips~}
      Server ${i}: ssh ${var.ansible_user}@${ip}
    %{endfor~}

    Router: ${var.enable_router ? "ssh ${var.ansible_user}@${module.router.public_ip}" : "disabled"}

    Clients: Use AWS Console or CLI to find ASG instance IPs
      aws ec2 describe-instances --filters "Name=tag:AnsibleGroup,Values=clients" --query 'Reservations[].Instances[].PublicIpAddress'

    SSH Key: ${var.ssh_key_name != "" ? "Using existing key: ${var.ssh_key_name}" : "Generated key in ./keys/"}

    ============================================
  EOT
}

# =============================================================================
# ALB OUTPUTS
# =============================================================================

output "alb_dns_name" {
  description = "ALB DNS name"
  value       = module.alb.alb_dns_name
}

# =============================================================================
# UI URLs (via ALB)
# =============================================================================

output "nomad_ui" {
  description = "Nomad UI URL (via ALB)"
  value       = module.alb.nomad_url
}

output "consul_ui" {
  description = "Consul UI URL (via ALB)"
  value       = module.alb.consul_url
}

output "vault_ui" {
  description = "Vault UI URL (via ALB)"
  value       = module.alb.vault_url
}

# Direct server access (backup)
output "nomad_ui_direct" {
  description = "Nomad UI URL (direct to server)"
  value       = "http://${module.servers.public_ips[0]}:4646"
}

output "consul_ui_direct" {
  description = "Consul UI URL (direct to server)"
  value       = "http://${module.servers.public_ips[0]}:8500"
}

output "vault_ui_direct" {
  description = "Vault UI URL (direct to server)"
  value       = "http://${module.servers.public_ips[0]}:8200"
}

# =============================================================================
# ANSIBLE INVENTORY DATA
# =============================================================================

output "ansible_inventory" {
  description = "Data for Ansible inventory"
  value = {
    servers = {
      hosts = zipmap(
        [for i in range(var.server_count) : "server-${i}"],
        [for i, ip in module.servers.public_ips : {
          ansible_host = ip
          private_ip   = module.servers.private_ips[i]
        }]
      )
      vars = {
        ansible_user            = var.ansible_user
        consul_server           = true
        vault_server            = true
        nomad_server            = true
        consul_bootstrap_expect = var.server_count
        nomad_bootstrap_expect  = var.server_count
      }
    }
    router = var.enable_router ? {
      hosts = {
        router-0 = {
          ansible_host = module.router.public_ip
          private_ip   = module.router.private_ip
        }
      }
      vars = {
        ansible_user = var.ansible_user
      }
    } : null
  }
}

# =============================================================================
# SCALING HELPER
# =============================================================================

output "scale_clients_command" {
  description = "Command to scale clients"
  value       = "aws autoscaling set-desired-capacity --auto-scaling-group-name ${module.clients.asg_name} --desired-capacity <COUNT>"
}
