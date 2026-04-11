# =============================================================================
# EPHEMERAL DEV ENVIRONMENT — EC2 + Docker (Free Tier)
# =============================================================================
# Spins up a single t2.micro EC2 instance with Docker for E2E testing.
# Designed to be created and destroyed per CI run.
# Cost: $0 (within AWS Free Tier — 750 hours/month t2.micro)
#
# Usage:
#   terraform init
#   terraform apply -auto-approve
#   # ... run tests against the EC2 public IP ...
#   terraform destroy -auto-approve
# =============================================================================

terraform {
  required_version = ">=1.7"

  # ===========================================================================
  # TERRAFORM CLOUD — Free Tier (Remote State + Locking)
  # ===========================================================================
  # Prerequisites:
  #   1. Create a free Terraform Cloud account at https://app.terraform.io
  #   2. Create an organization (or use an existing one)
  #   3. Create a workspace named "playwright-react-app-dev-ephemeral"
  #      → Settings > General > Execution Mode = "Local"
  #        (runs on the GH runner, TF Cloud only stores state)
  #   4. Generate a Team or User API token:
  #      → Settings > Teams > API Token (or User Settings > Tokens)
  #   5. Add the token as GitHub secret: TF_API_TOKEN
  #   6. Set GitHub secret or variable: TF_CLOUD_ORGANIZATION = "<your-org>"
  # ===========================================================================
  cloud {
    # Organization is set via TF_CLOUD_ORGANIZATION env var in the workflow

    workspaces {
      name = "playwright-react-app-dev-ephemeral"
    }
  }

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~>5.0"
    }
  }
}

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = local.common_tags
  }
}

locals {
  name_prefix = "${var.project_name}-dev"
  environment = "dev-ephemeral"

  # Computed values — DRY references used across resources
  vpc_cidr    = "10.0.0.0/16"
  public_cidr = "10.0.1.0/24"

  common_tags = {
    Environment = local.environment
    ManagedBy   = "Terraform"
    Project     = var.project_name
    TTL         = "1h"
    Owner       = "github-actions"
  }
}

# =============================================================================
# DATA SOURCES
# =============================================================================

data "aws_availability_zones" "available" {
  state = "available"
}

data "aws_ami" "amazon_linux" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-*-x86_64"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

# =============================================================================
# NETWORKING — VPC, Subnet, IGW (minimal)
# =============================================================================

resource "aws_vpc" "main" {
  cidr_block           = local.vpc_cidr
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-vpc"
  })
}

resource "aws_subnet" "public" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = local.public_cidr
  availability_zone       = data.aws_availability_zones.available.names[0]
  map_public_ip_on_launch = true

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-public"
  })
}

resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-igw"
  })
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-public-rt"
  })
}

resource "aws_route_table_association" "public" {
  subnet_id      = aws_subnet.public.id
  route_table_id = aws_route_table.public.id
}

# =============================================================================
# SECURITY GROUP — HTTP + SSH
# =============================================================================

resource "aws_security_group" "app" {
  name_prefix = "${local.name_prefix}-app-"
  description = "Allow HTTP and SSH for ephemeral dev environment"
  vpc_id      = aws_vpc.main.id

  ingress {
    description = "HTTP from anywhere"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "SSH for debugging"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-app-sg"
  })

  lifecycle {
    create_before_destroy = true
  }
}

# =============================================================================
# EC2 INSTANCE — t3.micro (Free Tier) + Docker
# =============================================================================

resource "aws_instance" "app" {
  ami                         = data.aws_ami.amazon_linux.id
  instance_type               = var.instance_type
  subnet_id                   = aws_subnet.public.id
  vpc_security_group_ids      = [aws_security_group.app.id]
  associate_public_ip_address = true

  user_data = <<-EOF
#!/bin/bash
exec > /var/log/user-data.log 2>&1
set -ex

# Install Docker + EC2 Instance Connect helper
# AL2023 minimal does NOT ship with ec2-instance-connect by default —
# without this the send-ssh-public-key API succeeds but the key is
# never written to authorized_keys, so SSH auth fails.
dnf update -y
dnf install -y docker ec2-instance-connect
systemctl start docker
systemctl enable docker
systemctl enable --now ec2-instance-connect || true

# Signal that Docker is ready
touch /tmp/docker-ready
EOF

  user_data_replace_on_change = true

  root_block_device {
    volume_size = 30
    volume_type = "gp3"
  }

  depends_on = [
    aws_internet_gateway.main,
  ]

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-app"
  })
}
