# =============================================================================
# PERFORMANCE ENVIRONMENT - VARIABLES
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
  default     = "10.1.0.0/16"  # Different CIDR to avoid conflicts
}

variable "instance_type" {
  description = "EC2 instance type"
  type        = string
  default     = "t3.small"  # Slightly larger for perf testing
}

variable "ssh_public_key_path" {
  description = "Path to SSH public key"
  type        = string
  default     = "~/.ssh/id_rsa.pub"
}

variable "allowed_ssh_cidr" {
  description = "CIDR for SSH access"
  type        = string
  default     = "0.0.0.0/0"
}

variable "custom_ami_id" {
  description = "Custom AMI ID from Packer"
  type        = string
  default     = ""
}

# =============================================================================
# DATABASE
# =============================================================================

variable "db_name" {
  description = "Database name"
  type        = string
  default     = "reactapp_perf"
}

variable "db_username" {
  description = "Database username"
  type        = string
  default     = "dbadmin"
}

variable "db_instance_class" {
  description = "RDS instance class"
  type        = string
  default     = "db.t3.micro"  # Smaller for cost savings
}
