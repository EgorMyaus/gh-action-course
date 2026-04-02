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
    tags = {
      Environment = "dev-ephemeral"
      ManagedBy   = "Terraform"
      Project     = var.project_name
      TTL         = "1h"
      Owner       = "github-actions"
    }
  }
}

locals {
  name_prefix = "${var.project_name}-dev"
  common_tags = {
    Environment = "dev-ephemeral"
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
  cidr_block           = "10.0.0.0/16"
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-vpc"
  })
}

resource "aws_subnet" "public" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.1.0/24"
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

# Install Docker and Git
yum update -y
yum install -y docker git
systemctl start docker
systemctl enable docker

# Clone repo and build Docker image
cd /tmp
git clone ${var.repo_url} app
cd app
git checkout ${var.commit_sha}
docker build -t react-app:${var.commit_sha} -t react-app:latest .

# Run container
docker run -d --name react-app -p 80:80 --restart unless-stopped react-app:latest

# Signal success
touch /tmp/deploy-ready
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
