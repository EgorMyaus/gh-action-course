# =============================================================================
# REPORTPORTAL ENVIRONMENT - VARIABLES
# =============================================================================

variable "project_name" {
  description = "Project name"
  type        = string
  default     = "playwright-react-app"
}

variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "us-east-1"
}

variable "vpc_cidr" {
  description = "VPC CIDR block"
  type        = string
  default     = "10.3.0.0/16"
}

# =============================================================================
# EC2 INSTANCE
# =============================================================================

variable "instance_type" {
  description = "EC2 instance type (t3.xlarge recommended for ReportPortal)"
  type        = string
  default     = "t3.xlarge"  # 4 vCPU, 16 GB RAM
}

variable "ami_id" {
  description = "Custom AMI ID (leave empty for latest Ubuntu)"
  type        = string
  default     = ""
}

variable "root_volume_size" {
  description = "Root volume size in GB"
  type        = number
  default     = 50  # Enough for PostgreSQL, OpenSearch data
}

variable "ssh_public_key_path" {
  description = "Path to SSH public key"
  type        = string
  default     = "~/.ssh/id_rsa.pub"
}

# =============================================================================
# ACCESS CONTROL
# =============================================================================

variable "allowed_ssh_cidr" {
  description = "CIDR for SSH access (restrict to your IP)"
  type        = string
  default     = "0.0.0.0/0"
}

variable "allowed_access_cidrs" {
  description = "CIDRs allowed to access ReportPortal UI"
  type        = list(string)
  default     = ["0.0.0.0/0"]
}
