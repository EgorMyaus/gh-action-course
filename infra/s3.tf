# =============================================================================
# TERRAFORM STATE STORAGE
# =============================================================================
# This S3 bucket stores Terraform state files securely.
# 
# IMPORTANT: Create this bucket FIRST before enabling the backend in provider.tf
# Run: terraform apply -target=aws_s3_bucket.terraform_state -target=aws_s3_bucket_versioning.terraform_state -target=aws_dynamodb_table.terraform_locks
# Then uncomment the backend block in provider.tf and run: terraform init -migrate-state
# =============================================================================

resource "random_string" "bucket_suffix" {
  length  = 8
  special = false
  upper   = false
}

# S3 Bucket for Terraform State
resource "aws_s3_bucket" "terraform_state" {
  bucket = "${var.project_name}-terraform-state-${random_string.bucket_suffix.result}"

  # Prevent accidental deletion
  lifecycle {
    prevent_destroy = false  # Set to true in production!
  }

  tags = merge(local.common_tags, {
    Name    = "${var.project_name}-terraform-state"
    Purpose = "Terraform State Storage"
  })
}

# Enable versioning for state file history
resource "aws_s3_bucket_versioning" "terraform_state" {
  bucket = aws_s3_bucket.terraform_state.id

  versioning_configuration {
    status = "Enabled"
  }
}

# Enable server-side encryption
resource "aws_s3_bucket_server_side_encryption_configuration" "terraform_state" {
  bucket = aws_s3_bucket.terraform_state.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

# Block all public access (state files should be private!)
resource "aws_s3_bucket_public_access_block" "terraform_state" {
  bucket = aws_s3_bucket.terraform_state.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# =============================================================================
# DYNAMODB TABLE FOR STATE LOCKING
# =============================================================================
# Prevents concurrent modifications to state file
# =============================================================================

resource "aws_dynamodb_table" "terraform_locks" {
  name         = "${var.project_name}-terraform-locks"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "LockID"

  attribute {
    name = "LockID"
    type = "S"
  }

  tags = merge(local.common_tags, {
    Name    = "${var.project_name}-terraform-locks"
    Purpose = "Terraform State Locking"
  })
}