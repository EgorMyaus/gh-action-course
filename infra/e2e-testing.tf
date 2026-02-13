# =============================================================================
# E2E TESTING INFRASTRUCTURE
# =============================================================================
# This file creates dedicated infrastructure for E2E testing.
# Only created when enable_e2e_infrastructure = true
#
# Best Practice: Separate E2E tests from production to:
#   - Save costs (E2E infra only runs when needed)
#   - Isolate test environments from production
#   - Scale test runners independently
#
# AMI Options:
#   - use_custom_ami = true  → Uses Packer-built AMI (faster boot)
#   - use_custom_ami = false → Uses base Ubuntu + user_data script
# =============================================================================

locals {
  # Use custom Packer AMI if provided, otherwise use base Ubuntu
  e2e_runner_ami = var.use_custom_ami && var.e2e_runner_ami_id != "" ? var.e2e_runner_ami_id : data.aws_ami.ubuntu.id
}

# =============================================================================
# SECURITY GROUP FOR E2E RUNNERS
# =============================================================================

resource "aws_security_group" "e2e" {
  count = var.enable_e2e_infrastructure ? 1 : 0

  name        = "${local.name_prefix}-e2e-sg"
  description = "Security group for E2E test runners"
  vpc_id      = aws_vpc.main.id

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-e2e-sg"
    Role = "e2e-testing"
  })
}

resource "aws_vpc_security_group_ingress_rule" "e2e_ssh" {
  count = var.enable_e2e_infrastructure ? 1 : 0

  security_group_id = aws_security_group.e2e[0].id
  description       = "Allow SSH access"
  cidr_ipv4         = var.allowed_ssh_cidr
  from_port         = 22
  to_port           = 22
  ip_protocol       = "tcp"
}

resource "aws_vpc_security_group_egress_rule" "e2e_all_outbound" {
  count = var.enable_e2e_infrastructure ? 1 : 0

  security_group_id = aws_security_group.e2e[0].id
  description       = "Allow all outbound traffic"
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1"
}

# =============================================================================
# E2E TEST RUNNER INSTANCE
# =============================================================================

resource "aws_instance" "e2e_runner" {
  count = var.enable_e2e_infrastructure ? 1 : 0

  ami                         = local.e2e_runner_ami
  instance_type               = var.e2e_instance_type
  subnet_id                   = aws_subnet.public.id
  vpc_security_group_ids      = [aws_security_group.e2e[0].id]
  key_name                    = aws_key_pair.web.key_name
  associate_public_ip_address = true

  root_block_device {
    delete_on_termination = true
    volume_size           = 30
    volume_type           = "gp3"
    encrypted             = true
  }

  # Only use user_data if NOT using custom Packer AMI
  user_data = var.use_custom_ami ? null : <<-EOF
    #!/bin/bash
    set -e

    exec > >(tee /var/log/user-data.log) 2>&1
    echo "Starting E2E runner setup at $(date)"

    apt-get update && apt-get upgrade -y

    # Install Node.js 18
    curl -fsSL https://deb.nodesource.com/setup_18.x | bash -
    apt-get install -y nodejs

    # Install Playwright
    npx playwright install-deps
    npx playwright install

    # Install Docker
    apt-get install -y docker.io docker-compose
    systemctl enable docker
    systemctl start docker
    usermod -aG docker ubuntu

    # Install tools
    apt-get install -y git curl wget vim htop jq unzip

    # AWS CLI v2
    curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
    unzip awscliv2.zip && ./aws/install && rm -rf aws awscliv2.zip

    echo "E2E runner setup completed at $(date)"
  EOF

  tags = merge(local.common_tags, {
    Name     = "${local.name_prefix}-e2e-runner"
    Role     = "e2e-testing"
    AMI_Type = var.use_custom_ami ? "packer-custom" : "base-ubuntu"
  })
}
