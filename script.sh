#!/usr/bin/env bash
# Copyright (c) HashiCorp, Inc.
# SPDX-License-Identifier: BUSL-1.1

# Disable interactive apt-get prompts
export DEBIAN_FRONTEND=noninteractive

# Define constants
CONFIG_DIR="/ops/shared/config"
CONSUL_VERSION="1.18.1"
VAULT_VERSION="1.18.0"
NOMAD_VERSION="1.9.0"
CONSUL_TEMPLATE_VERSION="0.39.1"
DOCKER_GPG_DIR="/etc/apt/keyrings"
DOCKER_LIST="/etc/apt/sources.list.d/docker.list"
NVIDIA_KEYRING="/usr/share/keyrings/nvidia-container-toolkit-keyring.gpg"
NOMAD_DRIVER_VIRT_URL="https://releases.hashicorp.com/nomad-driver-virt/0.0.1-beta.1/nomad-driver-virt_0.0.1-beta.1_linux_amd64.zip"
NOMAD_DRIVER_VIRT_ZIP="/tmp/nomad-driver-virt_0.0.1-beta.1_linux_amd64.zip"
NOMAD_PLUGIN_DIR="/opt/nomad/plugins"
NOMAD_DRIVER_EXEC2_URL="https://releases.hashicorp.com/nomad-driver-exec2/0.1.0-beta.2/nomad-driver-exec2_0.1.0-beta.2_linux_amd64.zip"
NOMAD_DRIVER_EXEC2_ZIP="/tmp/nomad-driver-exec2_0.1.0-beta.2_linux_amd64.zip"
CONFIG_FILE="/etc/nomad.d/nomad.hcl"
NOMAD_DATA_DIR="/tmp/nomaddata"

# Move to the desired working directory
cd /ops || { echo "Directory /ops does not exist. Exiting."; exit 1; }

# Install essential utilities
sudo apt-get update && sudo apt-get install -yq apt-utils gpg apt-transport-https ca-certificates gnupg curl build-essential unzip

# HashiCorp product installation
sudo apt-get update && sudo apt-get install -yq software-properties-common
wget -O- https://apt.releases.hashicorp.com/gpg | sudo gpg --dearmor -o /usr/share/keyrings/hashicorp-archive-keyring.gpg
echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $(lsb_release -cs) main" | sudo tee /etc/apt/sources.list.d/hashicorp.list
sudo apt-get update
sudo apt-get install -yq \
    consul="${CONSUL_VERSION}*" \
    vault="${VAULT_VERSION}*" \
    nomad="${NOMAD_VERSION}*" \
    consul-template="${CONSUL_TEMPLATE_VERSION}*"

# Install dependencies
sudo apt-get install -yq unzip tree redis jq tmux openjdk-8-jdk

# Disable the firewall if installed
sudo ufw disable || echo "ufw is not installed, skipping."

# Docker installation
sudo install -m 0755 -d ${DOCKER_GPG_DIR}
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o ${DOCKER_GPG_DIR}/docker.gpg
sudo chmod a+r ${DOCKER_GPG_DIR}/docker.gpg

# Add Docker's official repository
echo "deb [arch=$(dpkg --print-architecture) signed-by=${DOCKER_GPG_DIR}/docker.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | sudo tee ${DOCKER_LIST} > /dev/null
sudo apt-get update
sudo apt-get install -yq docker-ce docker-ce-cli containerd.io docker-buildx-plugin

# NVIDIA Docker installation (optional)
if [[ -n "${INSTALL_NVIDIA_DOCKER+x}" ]]; then
    # Install CUDA and NVIDIA Docker support
    wget https://developer.download.nvidia.com/compute/cuda/repos/ubuntu2204/x86_64/cuda-keyring_1.1-1_all.deb
    sudo dpkg -i cuda-keyring_1.1-1_all.deb

    echo "deb [signed-by=/usr/share/keyrings/cuda-archive-keyring.gpg] https://developer.download.nvidia.com/compute/cuda/repos/ubuntu2204/x86_64/ /" | sudo tee /etc/apt/sources.list.d/cuda-ubuntu2204-x86_64.list
    wget https://developer.download.nvidia.com/compute/cuda/repos/ubuntu2204/x86_64/cuda-ubuntu2204.pin
    sudo mv cuda-ubuntu2204.pin /etc/apt/preferences.d/cuda-repository-pin-600

    sudo apt-get update
    sudo apt-get install -yq cuda-toolkit nvidia-gds

    # NVIDIA container toolkit installation
    curl -fsSL https://nvidia.github.io/libnvidia-container/gpgkey | sudo gpg --dearmor -o ${NVIDIA_KEYRING}
    curl -s -L https://nvidia.github.io/libnvidia-container/stable/deb/nvidia-container-toolkit.list | \
    sed "s#deb https://#deb [signed-by=${NVIDIA_KEYRING}] https://#g" | sudo tee /etc/apt/sources.list.d/nvidia-container-toolkit.list

    sudo apt-get update
    sudo apt-get install -yq nvidia-container-toolkit

    sudo nvidia-ctk runtime configure --runtime=docker
    sudo systemctl restart docker
fi

# Download and install the precompiled nomad-driver-virt binary
wget -O ${NOMAD_DRIVER_VIRT_ZIP} ${NOMAD_DRIVER_VIRT_URL}
sudo unzip -o ${NOMAD_DRIVER_VIRT_ZIP} -d ${NOMAD_PLUGIN_DIR}
sudo chown -R nomad:nomad ${NOMAD_PLUGIN_DIR}
sudo chmod 0755 ${NOMAD_PLUGIN_DIR}

# Download and install the precompiled nomad-driver-exec2 binary
wget -O ${NOMAD_DRIVER_EXEC2_ZIP} ${NOMAD_DRIVER_EXEC2_URL}
sudo unzip -o ${NOMAD_DRIVER_EXEC2_ZIP} -d ${NOMAD_PLUGIN_DIR}
sudo chown -R nomad:nomad ${NOMAD_PLUGIN_DIR}
sudo chmod 0755 ${NOMAD_PLUGIN_DIR}

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

# Restart Nomad to apply the changes
sudo systemctl restart nomad