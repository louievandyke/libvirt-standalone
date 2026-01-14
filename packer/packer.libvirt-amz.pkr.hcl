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
  ami_name      = "nomad-libvirt-amazon-linux-2-{{timestamp}}"
  region        = var.region
  instance_type = "c5.large"
  source_ami_filter {
    filters = {
      virtualization-type = "hvm"
      name                = "amzn2-ami-hvm-*-x86_64-gp2"
      root-device-type    = "ebs"
    }
    owners      = ["137112412989"]  # Amazon's owner ID for Amazon Linux 2
    most_recent = true
  }
  ssh_username                = "ec2-user"  # Default user for Amazon Linux 2
  associate_public_ip_address = true

  tags = {
    Name = "nomad-libvirt-amazon-linux-2"
  }
}

build {
  sources = ["source.amazon-ebs.nomad-libvirt"]

  # Update the system
  provisioner "shell" {
    inline = [
      "sudo yum update -y"
    ]
  }

  # Create /ops directory
  provisioner "shell" {
    inline = [
      "sudo mkdir -p /ops",
      "sudo chown ec2-user:ec2-user /ops"
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

