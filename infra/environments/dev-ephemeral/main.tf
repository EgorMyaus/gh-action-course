# =============================================================================
# EPHEMERAL DEV ENVIRONMENT — EC2 + Docker (Free Tier)
# =============================================================================
# Spins up a single t3.micro EC2 instance with Docker for E2E testing.
# Designed to be created and destroyed per CI run.
# Cost: $0 (within AWS Free Tier — 750 hours/month t3.micro)
#
# Composed from two local modules:
#   - ../../modules/networking : VPC, public subnet, IGW, route table
#   - ../../modules/compute    : security group (HTTP + SSH), EC2 instance
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
  name_prefix    = "${var.project_name}-dev"
  environment    = "dev-ephemeral"
  use_custom_ami = var.custom_ami_id != ""
  ami_id         = local.use_custom_ami ? var.custom_ami_id : data.aws_ami.amazon_linux.id

  common_tags = {
    Environment = local.environment
    ManagedBy   = "Terraform"
    Project     = var.project_name
    TTL         = "1h"
    Owner       = "github-actions"
  }

  # Smart user_data: no-op if Docker is already baked into the AMI (Packer),
  # otherwise install Docker + ec2-instance-connect from scratch.
  user_data = <<-EOF
#!/bin/bash
exec > /var/log/user-data.log 2>&1
set -ex

if ! command -v docker &> /dev/null; then
  dnf update -y
  dnf install -y docker ec2-instance-connect
  systemctl enable docker
fi

systemctl start docker
touch /tmp/docker-ready
EOF
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
# MODULES
# =============================================================================

module "networking" {
  source = "../../modules/networking"

  name_prefix        = local.name_prefix
  common_tags        = local.common_tags
  vpc_cidr           = "10.0.0.0/16"
  public_subnet_cidr = "10.0.1.0/24"
  availability_zone  = data.aws_availability_zones.available.names[0]
}

module "compute" {
  source = "../../modules/compute"

  name_prefix   = local.name_prefix
  common_tags   = local.common_tags
  vpc_id        = module.networking.vpc_id
  subnet_id     = module.networking.public_subnet_id
  ami_id        = local.ami_id
  instance_type = var.instance_type
  user_data     = local.user_data
}
