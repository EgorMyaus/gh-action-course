# =============================================================================
# PERFORMANCE TESTING ENVIRONMENT
# =============================================================================
# Separate environment for load/stress/performance testing
# Includes database but uses smaller instance sizes to reduce cost
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

  # Uncomment after first apply to enable remote state
  # backend "s3" {
  #   bucket         = "BUCKET_NAME_FROM_OUTPUT"
  #   key            = "perf/terraform.tfstate"
  #   region         = "us-east-1"
  #   encrypt        = true
  #   dynamodb_table = "playwright-react-app-terraform-locks-perf"
  # }
}

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Environment = "perf"
      ManagedBy   = "Terraform"
      Project     = var.project_name
    }
  }
}

# =============================================================================
# LOCAL VALUES
# =============================================================================

locals {
  name_prefix = "${var.project_name}-perf"
  common_tags = {
    Environment = "perf"
    ManagedBy   = "Terraform"
    Project     = var.project_name
  }
}

# =============================================================================
# NETWORKING
# =============================================================================

module "networking" {
  source = "../../modules/networking"

  name_prefix        = local.name_prefix
  common_tags        = local.common_tags
  vpc_cidr           = var.vpc_cidr
  availability_zones = ["${var.aws_region}a", "${var.aws_region}b"]
  enable_nat_gateway = true  # Required for database in private subnet
}

# =============================================================================
# COMPUTE
# =============================================================================

module "compute" {
  source = "../../modules/compute"

  name_prefix         = local.name_prefix
  common_tags         = local.common_tags
  vpc_id              = module.networking.vpc_id
  subnet_id           = module.networking.public_subnet_ids[0]
  instance_type       = var.instance_type
  ssh_public_key_path = var.ssh_public_key_path
  allowed_ssh_cidr    = var.allowed_ssh_cidr
  custom_ami_id       = var.custom_ami_id
  root_volume_size    = 20

  user_data = <<-EOF
    #!/bin/bash
    set -e
    apt-get update
    apt-get install -y nginx docker.io docker-compose git
    systemctl enable nginx docker
    systemctl start nginx docker
    usermod -aG docker ubuntu
  EOF
}

# =============================================================================
# DATABASE (RDS PostgreSQL - smaller instance for perf testing)
# =============================================================================

module "database" {
  source = "../../modules/database"

  name_prefix           = local.name_prefix
  common_tags           = local.common_tags
  vpc_id                = module.networking.vpc_id
  private_subnet_ids    = module.networking.private_subnet_ids
  web_security_group_id = module.compute.security_group_id
  db_name               = var.db_name
  db_username           = var.db_username
  instance_class        = var.db_instance_class
  multi_az              = false  # Single AZ for cost savings
  backup_retention      = 1      # Minimal backup for perf env
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
  bucket = "${var.project_name}-tfstate-perf-${random_string.bucket_suffix.result}"

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
  name         = "${var.project_name}-terraform-locks-perf"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "LockID"

  attribute {
    name = "LockID"
    type = "S"
  }

  tags = local.common_tags
}
