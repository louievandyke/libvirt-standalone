#!/bin/bash
set -e

# Variables from Terraform
STACK_NAME="${stack_name}"
CONSUL_VERSION="${consul_version}"
NOMAD_VERSION="${nomad_version}"
NOMAD_DRIVER_VIRT_VERSION="${nomad_driver_virt_version}"
NOMAD_DRIVER_EXEC2_VERSION="${nomad_driver_exec2_version}"
NODE_CLASS="${node_class}"

# Disable interactive prompts
export DEBIAN_FRONTEND=noninteractive

# Get instance metadata
INSTANCE_ID=$(curl -s http://169.254.169.254/latest/meta-data/instance-id)
IP_ADDRESS=$(curl -s http://169.254.169.254/latest/meta-data/local-ipv4)
AZ=$(curl -s http://169.254.169.254/latest/meta-data/placement/availability-zone)
REGION=$(echo $AZ | sed 's/[a-z]$//')

# Set hostname
hostnamectl set-hostname "$${STACK_NAME}-client-$${INSTANCE_ID}"

# Add HashiCorp repository
apt-get update
apt-get install -y curl gnupg software-properties-common unzip

curl -fsSL https://apt.releases.hashicorp.com/gpg | gpg --dearmor -o /usr/share/keyrings/hashicorp-archive-keyring.gpg
echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $(lsb_release -cs) main" | tee /etc/apt/sources.list.d/hashicorp.list
apt-get update

# Install HashiCorp tools
apt-get install -y \
    consul="$${CONSUL_VERSION}*" \
    nomad="$${NOMAD_VERSION}*"

# Install Docker
apt-get install -y apt-transport-https ca-certificates
install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
chmod a+r /etc/apt/keyrings/docker.gpg
echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list
apt-get update
apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin

# Install libvirt
apt-get install -y qemu-kvm libvirt-daemon-system libvirt-clients bridge-utils virtinst libvirt-dev

# Create directories
mkdir -p /opt/consul/data /opt/nomad/data /opt/nomad/plugins /var/local/statics/images
chown -R consul:consul /opt/consul
chown -R nomad:nomad /opt/nomad

# Download and install Nomad plugins
NOMAD_PLUGIN_DIR="/opt/nomad/plugins"

# Install nomad-driver-virt
wget -q -O /tmp/nomad-driver-virt.zip "https://releases.hashicorp.com/nomad-driver-virt/$${NOMAD_DRIVER_VIRT_VERSION}/nomad-driver-virt_$${NOMAD_DRIVER_VIRT_VERSION}_linux_amd64.zip"
unzip -o /tmp/nomad-driver-virt.zip -d $${NOMAD_PLUGIN_DIR}
rm /tmp/nomad-driver-virt.zip

# Install nomad-driver-exec2
wget -q -O /tmp/nomad-driver-exec2.zip "https://releases.hashicorp.com/nomad-driver-exec2/$${NOMAD_DRIVER_EXEC2_VERSION}/nomad-driver-exec2_$${NOMAD_DRIVER_EXEC2_VERSION}_linux_amd64.zip"
unzip -o /tmp/nomad-driver-exec2.zip -d $${NOMAD_PLUGIN_DIR}
rm /tmp/nomad-driver-exec2.zip

# Remove non-binary files from plugins directory (LICENSE.txt etc)
find $${NOMAD_PLUGIN_DIR} -type f ! -executable -delete 2>/dev/null || true
rm -f $${NOMAD_PLUGIN_DIR}/*.txt 2>/dev/null || true

chown -R nomad:nomad $${NOMAD_PLUGIN_DIR}
chmod 755 $${NOMAD_PLUGIN_DIR}/*

# Configure Consul client
cat > /etc/consul.d/consul.hcl <<EOF
data_dir = "/opt/consul/data"
client_addr = "0.0.0.0"
bind_addr = "$${IP_ADDRESS}"

server = false

retry_join = ["provider=aws tag_key=ConsulAutoJoin tag_value=$${STACK_NAME}"]
EOF

chown consul:consul /etc/consul.d/consul.hcl
chmod 640 /etc/consul.d/consul.hcl

# Configure Nomad client
cat > /etc/nomad.d/nomad.hcl <<EOF
data_dir   = "/opt/nomad/data"
bind_addr  = "0.0.0.0"
plugin_dir = "/opt/nomad/plugins"

client {
  enabled    = true
  node_class = "$${NODE_CLASS}"

  options {
    "driver.raw_exec.enable"    = "1"
    "docker.privileged.enabled" = "true"
  }
}

plugin "nomad-driver-virt" {
  config {
    image_paths = ["/var/local/statics/images/"]
  }
}

plugin "nomad-driver-exec2" {
  config {
    unveil_defaults = true
    unveil_by_task  = true
  }
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

# Enable libvirt
systemctl enable libvirtd
systemctl start libvirtd

# Enable and start services
systemctl enable consul nomad docker
systemctl start consul

# Wait for Consul to join cluster
sleep 15
systemctl start nomad

echo "Client bootstrap complete"
