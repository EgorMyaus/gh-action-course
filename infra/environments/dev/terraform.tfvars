# =============================================================================
# Development Environment Configuration
# =============================================================================
# Usage: cd infra/environments/dev && terraform apply
# =============================================================================

project_name        = "playwright-react-app"
aws_region          = "us-east-1"

# Networking
vpc_cidr            = "10.0.0.0/16"
enable_nat_gateway  = false

# Compute
instance_type       = "t2.micro"
allowed_ssh_cidr    = "0.0.0.0/0"  # Restrict in production!
ssh_public_key_path = "~/.ssh/id_rsa.pub"

# Packer AMI (leave empty to use base Ubuntu with user_data)
custom_ami_id       = ""
