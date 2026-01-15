#!/bin/bash
set -e

# Variables from Terraform
SERVER_COUNT="${server_count}"
STACK_NAME="${stack_name}"
CONSUL_VERSION="${consul_version}"
VAULT_VERSION="${vault_version}"
NOMAD_VERSION="${nomad_version}"

# Disable interactive prompts
export DEBIAN_FRONTEND=noninteractive

# Get instance metadata
INSTANCE_ID=$(curl -s http://169.254.169.254/latest/meta-data/instance-id)
IP_ADDRESS=$(curl -s http://169.254.169.254/latest/meta-data/local-ipv4)
AZ=$(curl -s http://169.254.169.254/latest/meta-data/placement/availability-zone)
REGION=$(echo $AZ | sed 's/[a-z]$//')

# Set hostname
hostnamectl set-hostname "$${STACK_NAME}-server-$${INSTANCE_ID}"

# Add HashiCorp repository
apt-get update
apt-get install -y curl gnupg software-properties-common

curl -fsSL https://apt.releases.hashicorp.com/gpg | gpg --dearmor -o /usr/share/keyrings/hashicorp-archive-keyring.gpg
echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $(lsb_release -cs) main" | tee /etc/apt/sources.list.d/hashicorp.list
apt-get update

# Install HashiCorp tools
apt-get install -y \
    consul="$${CONSUL_VERSION}*" \
    vault="$${VAULT_VERSION}*" \
    nomad="$${NOMAD_VERSION}*"

# Create directories
mkdir -p /opt/consul/data /opt/vault/data /opt/nomad/data
chown -R consul:consul /opt/consul
chown -R vault:vault /opt/vault
chown -R nomad:nomad /opt/nomad

# Configure Consul server
cat > /etc/consul.d/consul.hcl <<EOF
data_dir = "/opt/consul/data"
client_addr = "0.0.0.0"
bind_addr = "$${IP_ADDRESS}"

server = true
bootstrap_expect = $${SERVER_COUNT}

retry_join = ["provider=aws tag_key=ConsulAutoJoin tag_value=$${STACK_NAME}"]

ui_config {
  enabled = true
}

connect {
  enabled = true
}
EOF

chown consul:consul /etc/consul.d/consul.hcl
chmod 640 /etc/consul.d/consul.hcl

# Configure Vault
cat > /etc/vault.d/vault.hcl <<EOF
storage "consul" {
  address = "127.0.0.1:8500"
  path    = "vault/"
}

listener "tcp" {
  address     = "0.0.0.0:8200"
  tls_disable = 1
}

api_addr = "http://$${IP_ADDRESS}:8200"
cluster_addr = "https://$${IP_ADDRESS}:8201"
ui = true
EOF

chown vault:vault /etc/vault.d/vault.hcl
chmod 640 /etc/vault.d/vault.hcl

# Configure Nomad server
cat > /etc/nomad.d/nomad.hcl <<EOF
data_dir  = "/opt/nomad/data"
bind_addr = "0.0.0.0"

server {
  enabled          = true
  bootstrap_expect = $${SERVER_COUNT}
}

consul {
  address = "127.0.0.1:8500"
}

vault {
  enabled = true
  address = "http://active.vault.service.consul:8200"
}
EOF

chown nomad:nomad /etc/nomad.d/nomad.hcl
chmod 640 /etc/nomad.d/nomad.hcl

# Enable and start services
systemctl enable consul vault nomad
systemctl start consul

# Wait for Consul to be ready before starting Vault and Nomad
sleep 10
systemctl start vault
sleep 5
systemctl start nomad

echo "Server bootstrap complete"
