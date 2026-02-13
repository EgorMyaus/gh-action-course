terraform {
  required_version = ">=1.7"

  # ===========================================================================
  # S3 BACKEND FOR REMOTE STATE (Enable after first apply)
  # ===========================================================================
  # STEP 1: Run `terraform apply` to create S3 bucket and DynamoDB table
  # STEP 2: Copy the bucket name from `terraform output terraform_state_bucket`
  # STEP 3: Uncomment the backend block below and update the bucket name
  # STEP 4: Run `terraform init -migrate-state` to migrate local state to S3
  # ===========================================================================
  # backend "s3" {
  #   bucket         = "REPLACE_WITH_BUCKET_NAME_FROM_OUTPUT"
  #   key            = "infra/terraform.tfstate"
  #   region         = "us-east-1"
  #   encrypt        = true
  #   dynamodb_table = "playwright-react-app-terraform-locks"
  # }

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
}

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      ManagedBy   = "Terraform"
      Project     = var.project_name
      Environment = var.environment
    }
  }
}