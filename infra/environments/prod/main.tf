# =============================================================================
# PRODUCTION ENVIRONMENT
# =============================================================================
# Full production infrastructure with database, cache, ALB, and monitoring
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
  #   key            = "prod/terraform.tfstate"
  #   region         = "us-east-1"
  #   encrypt        = true
  #   dynamodb_table = "playwright-react-app-terraform-locks-prod"
  # }
}

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Environment = "prod"
      ManagedBy   = "Terraform"
      Project     = var.project_name
    }
  }
}

# =============================================================================
# LOCAL VALUES
# =============================================================================

locals {
  name_prefix = "${var.project_name}-prod"
  common_tags = {
    Environment = "prod"
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
  enable_nat_gateway = true  # Required for private subnet resources
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
  root_volume_size    = 30
}

# =============================================================================
# DATABASE (RDS PostgreSQL)
# =============================================================================

module "database" {
  source = "../../modules/database"
  count  = var.enable_database ? 1 : 0

  name_prefix          = local.name_prefix
  common_tags          = local.common_tags
  vpc_id               = module.networking.vpc_id
  private_subnet_ids   = module.networking.private_subnet_ids
  web_security_group_id = module.compute.security_group_id
  db_name              = var.db_name
  db_username          = var.db_username
  instance_class       = var.db_instance_class
  multi_az             = var.db_multi_az
  backup_retention     = var.db_backup_retention
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
  bucket = "${var.project_name}-tfstate-prod-${random_string.bucket_suffix.result}"

  lifecycle {
    prevent_destroy = true
  }

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

resource "aws_s3_bucket_server_side_encryption_configuration" "terraform_state" {
  bucket = aws_s3_bucket.terraform_state.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_dynamodb_table" "terraform_locks" {
  name         = "${var.project_name}-terraform-locks-prod"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "LockID"

  attribute {
    name = "LockID"
    type = "S"
  }

  tags = local.common_tags
}
