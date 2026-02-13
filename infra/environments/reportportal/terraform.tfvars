# =============================================================================
# ReportPortal Infrastructure Configuration
# =============================================================================
# Usage: cd infra/environments/reportportal && terraform apply
# =============================================================================

project_name = "playwright-react-app"
aws_region   = "us-east-1"

# Networking
vpc_cidr = "10.3.0.0/16"

# EC2 Instance
# t3.xlarge: 4 vCPU, 16 GB RAM - recommended for ReportPortal
# t3.large:  2 vCPU, 8 GB RAM  - minimum (may have performance issues)
instance_type    = "t3.xlarge"
root_volume_size = 50

# SSH Key
ssh_public_key_path = "~/.ssh/id_rsa.pub"

# Access Control - RESTRICT THESE IN PRODUCTION!
allowed_ssh_cidr     = "0.0.0.0/0"  # Change to your IP: "x.x.x.x/32"
allowed_access_cidrs = ["0.0.0.0/0"]  # Change to your office/VPN CIDR
