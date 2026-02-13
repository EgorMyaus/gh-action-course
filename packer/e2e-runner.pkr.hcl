# =============================================================================
# PACKER TEMPLATE: E2E Test Runner AMI
# =============================================================================
# Creates a pre-baked AMI with Node.js, Playwright, and all dependencies.
# 
# Build command:
#   packer init e2e-runner.pkr.hcl
#   packer build e2e-runner.pkr.hcl
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
  default     = "t3.medium"
  description = "Instance type to use for building (needs more RAM for Playwright)"
}

variable "ami_name_prefix" {
  type        = string
  default     = "playwright-react-app-e2e"
  description = "Prefix for the AMI name"
}

variable "node_version" {
  type        = string
  default     = "18"
  description = "Node.js major version to install"
}

# =============================================================================
# DATA SOURCE: Find latest Ubuntu 20.04 AMI
# =============================================================================

data "amazon-ami" "ubuntu" {
  filters = {
    name                = "ubuntu/images/hvm-ssd/ubuntu-focal-20.04-amd64-server-*"
    virtualization-type = "hvm"
    root-device-type    = "ebs"
  }
  owners      = ["099720109477"]  # Canonical
  most_recent = true
  region      = var.aws_region
}

# =============================================================================
# SOURCE: EC2 Instance for Building
# =============================================================================

source "amazon-ebs" "e2e_runner" {
  ami_name        = "${var.ami_name_prefix}-{{timestamp}}"
  ami_description = "E2E test runner AMI with Node.js, Playwright, and Docker pre-installed"
  instance_type   = var.instance_type
  region          = var.aws_region
  source_ami      = data.amazon-ami.ubuntu.id

  ssh_username = "ubuntu"

  tags = {
    Name        = "${var.ami_name_prefix}-{{timestamp}}"
    Builder     = "Packer"
    Project     = "playwright-react-app"
    Role        = "e2e-runner"
    Base_AMI    = data.amazon-ami.ubuntu.id
    Node_Version = var.node_version
    Build_Date  = "{{timestamp}}"
  }

  # AMI settings
  ami_virtualization_type = "hvm"
  ena_support             = true

  # Launch block device mappings (larger for E2E)
  launch_block_device_mappings {
    device_name           = "/dev/sda1"
    volume_size           = 30
    volume_type           = "gp3"
    delete_on_termination = true
    encrypted             = true
  }
}

# =============================================================================
# BUILD: Provisioners
# =============================================================================

build {
  name    = "e2e-runner"
  sources = ["source.amazon-ebs.e2e_runner"]

  # Update system packages
  provisioner "shell" {
    inline = [
      "echo '=== Updating system packages ==='",
      "sudo apt-get update",
      "sudo DEBIAN_FRONTEND=noninteractive apt-get upgrade -y"
    ]
  }

  # Install essential tools
  provisioner "shell" {
    inline = [
      "echo '=== Installing essential tools ==='",
      "sudo apt-get install -y curl wget git vim htop unzip jq apt-transport-https ca-certificates gnupg lsb-release"
    ]
  }

  # Install Node.js
  provisioner "shell" {
    inline = [
      "echo '=== Installing Node.js ${var.node_version} ==='",
      "curl -fsSL https://deb.nodesource.com/setup_${var.node_version}.x | sudo -E bash -",
      "sudo apt-get install -y nodejs",
      "node --version",
      "npm --version"
    ]
  }

  # Install Playwright system dependencies
  provisioner "shell" {
    inline = [
      "echo '=== Installing Playwright system dependencies ==='",
      "sudo npx playwright install-deps"
    ]
  }

  # Install Playwright browsers globally
  provisioner "shell" {
    inline = [
      "echo '=== Installing Playwright browsers ==='",
      "sudo npm install -g playwright",
      "npx playwright install chromium firefox webkit"
    ]
  }

  # Install Docker
  provisioner "shell" {
    inline = [
      "echo '=== Installing Docker ==='",
      "curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg",
      "echo \"deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable\" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null",
      "sudo apt-get update",
      "sudo apt-get install -y docker-ce docker-ce-cli containerd.io",
      "sudo systemctl enable docker",
      "sudo usermod -aG docker ubuntu"
    ]
  }

  # Install Docker Compose
  provisioner "shell" {
    inline = [
      "echo '=== Installing Docker Compose ==='",
      "sudo curl -L \"https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)\" -o /usr/local/bin/docker-compose",
      "sudo chmod +x /usr/local/bin/docker-compose"
    ]
  }

  # Install AWS CLI v2
  provisioner "shell" {
    inline = [
      "echo '=== Installing AWS CLI v2 ==='",
      "curl \"https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip\" -o \"awscliv2.zip\"",
      "unzip awscliv2.zip",
      "sudo ./aws/install",
      "rm -rf aws awscliv2.zip"
    ]
  }

  # Create test runner script
  provisioner "shell" {
    inline = [
      "echo '=== Creating test runner helper script ==='",
      "sudo tee /usr/local/bin/run-e2e-tests > /dev/null <<'EOF'",
      "#!/bin/bash",
      "set -e",
      "",
      "# Usage: run-e2e-tests <repo-url> <branch> <base-url>",
      "REPO_URL=$1",
      "BRANCH=${2:-main}",
      "BASE_URL=${3:-http://localhost}",
      "",
      "echo \"Cloning repository...\"",
      "git clone --branch $BRANCH --depth 1 $REPO_URL /tmp/test-repo",
      "cd /tmp/test-repo/e2e",
      "",
      "echo \"Installing dependencies...\"",
      "npm ci",
      "",
      "echo \"Running E2E tests against $BASE_URL...\"",
      "BASE_URL=$BASE_URL npx playwright test",
      "",
      "echo \"Cleaning up...\"",
      "rm -rf /tmp/test-repo",
      "EOF",
      "sudo chmod +x /usr/local/bin/run-e2e-tests"
    ]
  }

  # Cleanup
  provisioner "shell" {
    inline = [
      "echo '=== Cleaning up ==='",
      "sudo apt-get clean",
      "sudo rm -rf /var/lib/apt/lists/*",
      "sudo rm -rf /tmp/*",
      "sudo rm -rf ~/.npm/_cacache"
    ]
  }

  # Verify installations
  provisioner "shell" {
    inline = [
      "echo '=== Verifying installations ==='",
      "node --version",
      "npm --version",
      "npx playwright --version",
      "docker --version",
      "docker-compose --version",
      "aws --version",
      "echo '=== E2E Runner AMI build complete ==='"
    ]
  }
}
