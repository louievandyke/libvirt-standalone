{
  "builders": [
    {
      "type": "amazon-ebs",
      "region": "us-west-1",  # Replace with your target region
      "instance_type": "c5.metal",  # Using c5.metal instance
      "source_ami_filter": {
        "filters": {
          "virtualization-type": "hvm",
          "name": "amzn2-ami-hvm-*-x86_64-gp2",  # Amazon Linux 2 AMI
          "root-device-type": "ebs"
        },
        "owners": [
          "137112412989"
        ],  # Amazon Linux 2 AMI owner ID
        "most_recent": true
      },
      "ssh_username": "ec2-user",  # Default user for Amazon Linux 2
      "ami_name": "hc-libvirt-nomad",
      "ami_description": "libvirt copied image for Nomad setup.",
      "ena_support": true,
      "volume_type": "gp3",
      "root_device_name": "/dev/sda1",
      "ami_block_device_mappings": [
        {
          "device_name": "/dev/sda1",
          "ebs": {
            "volume_size": 8,
            "delete_on_termination": true,
            "volume_type": "gp3"
          }
        },
        {
          "device_name": "/dev/sdb",
          "virtual_name": "ephemeral0"
        },
        {
          "device_name": "/dev/sdc",
          "virtual_name": "ephemeral1"
        }
      ]
    }
  ],
  "provisioners": [
    {
      "type": "shell",
      "inline": [
        "sudo yum update -y",  # Update the package list
        "sudo yum install -y libvirt",  # Install libvirt on Amazon Linux 2
        "sudo systemctl enable libvirtd",  # Enable libvirt service
        "sudo systemctl start libvirtd"  # Start the libvirt service
      ]
    }
  ]
}
