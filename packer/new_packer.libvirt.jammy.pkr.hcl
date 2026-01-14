# Set up variables
variable "region" {
  default = "us-west-1"
}

# Variable to control script execution
variable "run_script" {
  type    = bool
  default = false  # Set to true if you want to run the script during the build
}

source "amazon-ebs" "nomad-libvirt" {
  ami_name      = "nomad-libvirt-qemu-ubuntu-jammy-{{timestamp}}"
  region        = var.region
  instance_type = "c5.large"
  source_ami_filter {
    filters = {
      virtualization-type = "hvm"
      name                = "ubuntu/images/*ubuntu-jammy-22.04-amd64-server-*"
      root-device-type    = "ebs"
    }
    owners      = ["099720109477"]  # Canonical's owner ID for Ubuntu
    most_recent = true
  }
  ssh_username               = "ubuntu"
  associate_public_ip_address = true

  tags = {
    Name = "nomad-libvirt-ubuntu-jam"
  }
}

build {
  sources = ["source.amazon-ebs.nomad-libvirt"]

  # Ensure universe repository is enabled and upgrade the system
  provisioner "shell" {
    inline = [
      "sudo add-apt-repository universe",
      "sudo apt update && sudo apt upgrade -y"
    ]
  }

  # Create /ops directory
  provisioner "shell" {
    inline = [
      "sudo mkdir -p /ops",
      "sudo chown ubuntu:ubuntu /ops"
    ]
  }

  # Upload the script to /ops directory
  provisioner "file" {
    source      = "virtlib_setup.sh"  # Adjust with your script's path on the local machine
    destination = "/ops/script.sh"
  }

  # Make the script executable
  provisioner "shell" {
    inline = [
      "sudo chmod +x /ops/script.sh"
    ]
  }

  # Conditionally run the script based on the run_script variable
  provisioner "shell" {
    inline = [
      "${var.run_script ? "sudo /bin/bash /ops/script.sh" : "echo 'Skipping script execution'"}"
    ]
  }
}
