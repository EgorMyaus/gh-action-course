# =============================================================================
# Performance Testing Environment Configuration
# =============================================================================
# Usage: cd infra/environments/perf && terraform apply
# 
# This environment is specifically for performance/load testing.
# It includes a database for realistic testing but uses smaller
# instance sizes to reduce costs.
# =============================================================================

project_name        = "playwright-react-app"
aws_region          = "us-east-1"

# Networking - Uses different CIDR to allow peering if needed
vpc_cidr            = "10.1.0.0/16"

# Compute - Slightly larger for handling load tests
instance_type       = "t3.small"
allowed_ssh_cidr    = "0.0.0.0/0"  # Restrict in production!
ssh_public_key_path = "~/.ssh/id_rsa.pub"

# Packer AMI (recommended)
custom_ami_id       = ""

# Database - Single AZ, minimal backups for cost savings
db_name             = "reactapp_perf"
db_username         = "dbadmin"
db_instance_class   = "db.t3.micro"
