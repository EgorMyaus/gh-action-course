# =============================================================================
# REPORTPORTAL INFRASTRUCTURE
# =============================================================================
# Dedicated EC2 instance for ReportPortal test reporting platform
# Includes: PostgreSQL, MinIO, RabbitMQ, OpenSearch (all in Docker)
# =============================================================================
# Resource Requirements:
#   - t3.xlarge (4 vCPU, 16 GB RAM) minimum recommended
#   - 50+ GB EBS storage for data persistence
# =============================================================================

terraform {
  required_version = ">=1.7"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~>5.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~>3.0"
    }
  }

  # Uncomment after first apply
  # backend "s3" {
  #   bucket         = "BUCKET_NAME_FROM_OUTPUT"
  #   key            = "reportportal/terraform.tfstate"
  #   region         = "us-east-1"
  #   encrypt        = true
  #   dynamodb_table = "playwright-react-app-terraform-locks-reportportal"
  # }
}

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Environment = "reportportal"
      ManagedBy   = "Terraform"
      Project     = var.project_name
    }
  }
}

# =============================================================================
# LOCAL VALUES
# =============================================================================

locals {
  name_prefix = "${var.project_name}-reportportal"
  common_tags = {
    Environment = "reportportal"
    ManagedBy   = "Terraform"
    Project     = var.project_name
  }
}

# =============================================================================
# VPC & NETWORKING
# =============================================================================

resource "aws_vpc" "reportportal" {
  cidr_block           = var.vpc_cidr
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-vpc"
  })
}

resource "aws_internet_gateway" "reportportal" {
  vpc_id = aws_vpc.reportportal.id

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-igw"
  })
}

resource "aws_subnet" "public" {
  vpc_id                  = aws_vpc.reportportal.id
  cidr_block              = cidrsubnet(var.vpc_cidr, 8, 1)
  availability_zone       = "${var.aws_region}a"
  map_public_ip_on_launch = true

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-public-subnet"
  })
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.reportportal.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.reportportal.id
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
# SECURITY GROUP
# =============================================================================

resource "aws_security_group" "reportportal" {
  name        = "${local.name_prefix}-sg"
  description = "Security group for ReportPortal server"
  vpc_id      = aws_vpc.reportportal.id

  # SSH
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.allowed_ssh_cidr]
    description = "SSH access"
  }

  # ReportPortal UI (via Traefik)
  ingress {
    from_port   = 8080
    to_port     = 8080
    protocol    = "tcp"
    cidr_blocks = var.allowed_access_cidrs
    description = "ReportPortal UI"
  }

  # Traefik Dashboard
  ingress {
    from_port   = 8081
    to_port     = 8081
    protocol    = "tcp"
    cidr_blocks = [var.allowed_ssh_cidr]
    description = "Traefik Dashboard"
  }

  # HTTPS (optional, for future TLS)
  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = var.allowed_access_cidrs
    description = "HTTPS"
  }

  # Outbound
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow all outbound"
  }

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-sg"
  })
}

# =============================================================================
# SSH KEY PAIR
# =============================================================================

resource "aws_key_pair" "reportportal" {
  key_name   = "${local.name_prefix}-key"
  public_key = file(var.ssh_public_key_path)

  tags = local.common_tags
}

# =============================================================================
# EC2 INSTANCE
# =============================================================================

resource "aws_instance" "reportportal" {
  ami                    = var.ami_id != "" ? var.ami_id : data.aws_ami.ubuntu.id
  instance_type          = var.instance_type
  subnet_id              = aws_subnet.public.id
  vpc_security_group_ids = [aws_security_group.reportportal.id]
  key_name               = aws_key_pair.reportportal.key_name

  root_block_device {
    volume_size           = var.root_volume_size
    volume_type           = "gp3"
    encrypted             = true
    delete_on_termination = false

    tags = merge(local.common_tags, {
      Name = "${local.name_prefix}-root-volume"
    })
  }

  user_data = <<-EOF
    #!/bin/bash
    set -e

    # Update system
    apt-get update
    apt-get upgrade -y

    # Install Docker
    apt-get install -y apt-transport-https ca-certificates curl gnupg lsb-release
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
    echo "deb [arch=amd64 signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list
    apt-get update
    apt-get install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin

    # Configure Docker
    systemctl enable docker
    systemctl start docker
    usermod -aG docker ubuntu

    # Set vm.max_map_count for OpenSearch
    echo "vm.max_map_count=262144" >> /etc/sysctl.conf
    sysctl -w vm.max_map_count=262144

    # Create ReportPortal directory
    mkdir -p /opt/reportportal
    chown ubuntu:ubuntu /opt/reportportal

    # Signal completion
    echo "ReportPortal server ready" > /tmp/setup-complete
  EOF

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-server"
  })

  lifecycle {
    ignore_changes = [ami]
  }
}

# =============================================================================
# ELASTIC IP
# =============================================================================

resource "aws_eip" "reportportal" {
  instance = aws_instance.reportportal.id
  domain   = "vpc"

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-eip"
  })
}

# =============================================================================
# DATA SOURCES
# =============================================================================

data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"] # Canonical

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

# =============================================================================
# TERRAFORM STATE STORAGE
# =============================================================================

resource "random_string" "bucket_suffix" {
  length  = 8
  special = false
  upper   = false
}

resource "aws_s3_bucket" "terraform_state" {
  bucket = "${var.project_name}-tfstate-rp-${random_string.bucket_suffix.result}"

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-terraform-state"
  })
}

resource "aws_s3_bucket_versioning" "terraform_state" {
  bucket = aws_s3_bucket.terraform_state.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_dynamodb_table" "terraform_locks" {
  name         = "${var.project_name}-terraform-locks-reportportal"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "LockID"

  attribute {
    name = "LockID"
    type = "S"
  }

  tags = local.common_tags
}
