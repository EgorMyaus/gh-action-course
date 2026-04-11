# =============================================================================
# PACKER TEMPLATE: Web Server AMI (AL2023 + Docker)
# =============================================================================
# Creates a pre-baked AMI with Docker and EC2 Instance Connect installed.
# Matches the user_data from infra/environments/dev-ephemeral/main.tf but
# bakes everything at build time so EC2 boots ready to `docker pull` immediately.
#
# Build command:
#   packer init web-server.pkr.hcl
#   packer build -var-file=variables.pkrvars.hcl web-server.pkr.hcl
#
# Cost note (Option A — ephemeral AMI):
#   The AMI is built, used, and deregistered within a single CI run.
#   EBS snapshot exists for ~20 minutes → effectively $0.
# =============================================================================

packer {
  required_plugins {
    amazon = {
      source  = "github.com/hashicorp/amazon"
      version = "~> 1.0"
    }
  }
}

# =============================================================================
# VARIABLES
# =============================================================================

variable "aws_region" {
  type        = string
  default     = "us-east-1"
  description = "AWS region to build the AMI in"
}

variable "instance_type" {
  type        = string
  default     = "t3.micro"
  description = "Instance type to use for building (Free Tier eligible)"
}

variable "ami_name_prefix" {
  type        = string
  default     = "playwright-react-app-web"
  description = "Prefix for the AMI name"
}

# =============================================================================
# DATA SOURCE: Find latest Amazon Linux 2023 AMI
# =============================================================================

data "amazon-ami" "al2023" {
  filters = {
    name                = "al2023-ami-*-x86_64"
    virtualization-type = "hvm"
    root-device-type    = "ebs"
  }
  owners      = ["amazon"]
  most_recent = true
  region      = var.aws_region
}

# =============================================================================
# SOURCE: EC2 Instance for Building
# =============================================================================

source "amazon-ebs" "web_server" {
  ami_name        = "${var.ami_name_prefix}-{{timestamp}}"
  ami_description = "AL2023 with Docker + EC2 Instance Connect pre-installed"
  instance_type   = var.instance_type
  region          = var.aws_region
  source_ami      = data.amazon-ami.al2023.id

  ssh_username = "ec2-user"

  tags = {
    Name       = "${var.ami_name_prefix}-{{timestamp}}"
    Builder    = "Packer"
    Project    = "playwright-react-app"
    Role       = "web-server"
    Base_AMI   = data.amazon-ami.al2023.id
    Build_Date = "{{timestamp}}"
  }

  launch_block_device_mappings {
    device_name           = "/dev/xvda"
    volume_size           = 10
    volume_type           = "gp3"
    delete_on_termination = true
  }
}

# =============================================================================
# BUILD: Provisioners
# =============================================================================

build {
  name    = "web-server"
  sources = ["source.amazon-ebs.web_server"]

  # Install Docker + EC2 Instance Connect (mirrors user_data from main.tf)
  provisioner "shell" {
    inline = [
      "echo '=== Updating system packages ==='",
      "sudo dnf update -y",

      "echo '=== Installing Docker + EC2 Instance Connect ==='",
      "sudo dnf install -y docker ec2-instance-connect",

      "echo '=== Enabling services ==='",
      "sudo systemctl enable docker",
      "sudo systemctl enable ec2-instance-connect || true",

      "echo '=== Cleanup ==='",
      "sudo dnf clean all",
      "sudo rm -rf /var/cache/dnf /tmp/*",

      "echo '=== Verifying installations ==='",
      "docker --version",
      "echo '=== Web Server AMI build complete ==='"
    ]
  }
}
