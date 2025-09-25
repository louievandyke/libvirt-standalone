#!/usr/bin/env bash
# Copyright (c) HashiCorp, Inc.
# SPDX-License-Identifier: BUSL-1.1

# Disable interactive apt-get prompts
export DEBIAN_FRONTEND=noninteractive

# Define constants
CONFIG_FILE="/etc/nomad.d/nomad.hcl"
NOMAD_PLUGIN_DIR="/opt/nomad/plugins"
NOMAD_DATA_DIR="/tmp/nomaddata"  # Temporary workaround data directory
CONSUL_VERSION="1.18.1"
VAULT_VERSION="1.18.0"
NOMAD_VERSION="1.9.0"
CONSUL_TEMPLATE_VERSION="0.39.1"
DOCKER_GPG_DIR="/etc/apt/keyrings"
DOCKER_LIST="/etc/apt/sources.list.d/docker.list"
NOMAD_DRIVER_VIRT_VERSION="0.0.1-beta.1"
NOMAD_DRIVER_EXEC2_VERSION="0.1.0-beta.2"

# URLs for the nomad-driver-virt and nomad-driver-exec2 binaries
NOMAD_DRIVER_VIRT_URL="https://releases.hashicorp.com/nomad-driver-virt/${NOMAD_DRIVER_VIRT_VERSION}/nomad-driver-virt_${NOMAD_DRIVER_VIRT_VERSION}_linux_amd64.zip"
NOMAD_DRIVER_EXEC2_URL="https://releases.hashicorp.com/nomad-driver-exec2/${NOMAD_DRIVER_EXEC2_VERSION}/nomad-driver-exec2_${NOMAD_DRIVER_EXEC2_VERSION}_linux_amd64.zip"

# Create plugin directory if it doesn't exist
sudo mkdir -p ${NOMAD_PLUGIN_DIR}

# Install essential utilities
sudo apt-get update && sudo apt-get install -yq apt-utils gpg apt-transport-https ca-certificates gnupg curl build-essential unzip

# Function to download, unzip, and move driver to the plugin directory
install_nomad_driver () {
  local driver_name=$1
  local driver_url=$2
  local driver_zip="/tmp/${driver_name}.zip"

  echo "Installing ${driver_name}..."

  # Download the driver binary
  wget -O ${driver_zip} ${driver_url}

  # Unzip the driver
  sudo unzip -o ${driver_zip} -d ${NOMAD_PLUGIN_DIR}

  # Set correct permissions
  sudo chown -R nomad:nomad ${NOMAD_PLUGIN_DIR}
  sudo chmod 0755 ${NOMAD_PLUGIN_DIR}

  # Clean up
  rm ${driver_zip}
}

# Install nomad-driver-virt
install_nomad_driver "nomad-driver-virt" ${NOMAD_DRIVER_VIRT_URL}

# Install nomad-driver-exec2
install_nomad_driver "nomad-driver-exec2" ${NOMAD_DRIVER_EXEC2_URL}

# Update Nomad configuration with data_dir, plugin settings, and server block
echo "Updating Nomad configuration..."

sudo bash -c "cat <<EOF > ${CONFIG_FILE}
data_dir  = \"${NOMAD_DATA_DIR}\"
#data_dir  = \"/opt/nomad/data\"
bind_addr = \"0.0.0.0\"
log_level  = \"DEBUG\"
plugin_dir = \"${NOMAD_PLUGIN_DIR}\"

plugin \"nomad-driver-virt\" {
  config {
    #data_dir    = \"/tmp/virtdata\"
    #data_dir    = \"/opt/ubuntu/virt_temp\"
    image_paths = [\"/var/local/statics/images/\"]
  }
}

plugin \"nomad-driver-exec2\" {
  config {
    unveil_defaults = true
    unveil_by_task  = true
  }
}

# Enable the server block with bootstrap_expect
server {
  enabled = true
  bootstrap_expect = 1
}

# Enable the client
client {
  enabled = true
  options {
    \"driver.raw_exec.enable\"    = \"1\"
    \"docker.privileged.enabled\" = \"true\"
  }
}

consul {
  address = \"127.0.0.1:8500\"
}

vault {
  enabled = true
  address = \"http://active.vault.service.consul:8200\"
}
EOF"

# Set permissions on the data directory
sudo mkdir -p ${NOMAD_DATA_DIR}
sudo chmod 777 -R ${NOMAD_DATA_DIR}

# Restart Nomad service to apply changes
echo "Restarting Nomad..."
sudo systemctl restart nomad

echo "Nomad configuration updated, drivers installed, and data directory permissions set."
