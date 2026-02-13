# =============================================================================
# DEVELOPMENT ENVIRONMENT - VARIABLES
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
  default     = "10.0.0.0/16"
}

variable "enable_nat_gateway" {
  description = "Enable NAT Gateway"
  type        = bool
  default     = false
}

variable "instance_type" {
  description = "EC2 instance type"
  type        = string
  default     = "t2.micro"
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
  description = "Custom AMI ID from Packer (leave empty for base Ubuntu)"
  type        = string
  default     = ""
}
