# =============================================================================
# Production Environment Configuration
# =============================================================================
# Usage: cd infra/environments/prod && terraform apply
# =============================================================================

project_name        = "playwright-react-app"
aws_region          = "us-east-1"

# Networking
vpc_cidr            = "10.0.0.0/16"

# Compute
instance_type       = "t3.small"
allowed_ssh_cidr    = "YOUR_OFFICE_IP/32"  # IMPORTANT: Replace with actual IP!
ssh_public_key_path = "~/.ssh/id_rsa.pub"

# Packer AMI (recommended for production)
custom_ami_id       = ""  # Set to ami-xxxxx from Packer build

# Database
enable_database     = true
db_name             = "reactapp"
db_username         = "dbadmin"
db_instance_class   = "db.t3.micro"
db_multi_az         = true
db_backup_retention = 14
