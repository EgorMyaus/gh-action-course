# =============================================================================
# PACKER TEMPLATE: Web Server AMI
# =============================================================================
# Creates a pre-baked AMI with NGINX, Docker, and all dependencies installed.
# 
# Build command:
#   packer init web-server.pkr.hcl
#   packer build web-server.pkr.hcl
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
  default     = "t2.micro"
  description = "Instance type to use for building"
}

variable "ami_name_prefix" {
  type        = string
  default     = "playwright-react-app-web"
  description = "Prefix for the AMI name"
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

source "amazon-ebs" "web_server" {
  ami_name        = "${var.ami_name_prefix}-{{timestamp}}"
  ami_description = "Web server AMI with NGINX and Docker pre-installed"
  instance_type   = var.instance_type
  region          = var.aws_region
  source_ami      = data.amazon-ami.ubuntu.id

  ssh_username = "ubuntu"

  tags = {
    Name        = "${var.ami_name_prefix}-{{timestamp}}"
    Builder     = "Packer"
    Project     = "playwright-react-app"
    Role        = "web-server"
    Base_AMI    = data.amazon-ami.ubuntu.id
    Build_Date  = "{{timestamp}}"
  }

  # AMI settings
  ami_virtualization_type = "hvm"
  ena_support             = true

  # Launch block device mappings
  launch_block_device_mappings {
    device_name           = "/dev/sda1"
    volume_size           = 20
    volume_type           = "gp3"
    delete_on_termination = true
    encrypted             = true
  }
}

# =============================================================================
# BUILD: Provisioners
# =============================================================================

build {
  name    = "web-server"
  sources = ["source.amazon-ebs.web_server"]

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

  # Install NGINX
  provisioner "shell" {
    inline = [
      "echo '=== Installing NGINX ==='",
      "sudo apt-get install -y nginx",
      "sudo systemctl enable nginx"
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

  # Create default NGINX page
  provisioner "shell" {
    inline = [
      "echo '=== Creating default NGINX page ==='",
      "sudo tee /var/www/html/index.html > /dev/null <<'EOF'",
      "<!DOCTYPE html>",
      "<html>",
      "<head>",
      "  <title>React App - Ready</title>",
      "  <style>",
      "    body { font-family: Arial, sans-serif; text-align: center; padding: 50px; }",
      "    h1 { color: #333; }",
      "    .status { color: #4CAF50; }",
      "  </style>",
      "</head>",
      "<body>",
      "  <h1>🚀 Web Server Ready!</h1>",
      "  <p class=\"status\">NGINX and Docker are running.</p>",
      "  <p>Deploy your React app to replace this page.</p>",
      "</body>",
      "</html>",
      "EOF"
    ]
  }

  # Cleanup
  provisioner "shell" {
    inline = [
      "echo '=== Cleaning up ==='",
      "sudo apt-get clean",
      "sudo rm -rf /var/lib/apt/lists/*",
      "sudo rm -rf /tmp/*"
    ]
  }

  # Verify installations
  provisioner "shell" {
    inline = [
      "echo '=== Verifying installations ==='",
      "nginx -v",
      "docker --version",
      "docker-compose --version",
      "aws --version",
      "echo '=== Web Server AMI build complete ==='"
    ]
  }
}
