# =============================================================================
# INPUT VARIABLES
# =============================================================================

# =============================================================================
# GENERAL CONFIGURATION
# =============================================================================

variable "project_name" {
  description = "Project name used for resource naming and tagging"
  type        = string
  default     = "playwright-react-app"
}

variable "environment" {
  description = "Environment name (dev, staging, prod)"
  type        = string
  default     = "dev"

  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "Environment must be dev, staging, or prod."
  }
}

variable "aws_region" {
  description = "AWS region for all resources"
  type        = string
  default     = "us-east-1"
}

# =============================================================================
# NETWORKING CONFIGURATION
# =============================================================================

variable "vpc_cidr" {
  description = "CIDR block for the VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "public_subnet_cidr" {
  description = "CIDR block for the public subnet"
  type        = string
  default     = "10.0.1.0/24"
}

variable "private_subnet_cidr" {
  description = "CIDR block for the private subnet"
  type        = string
  default     = "10.0.2.0/24"
}

variable "availability_zone" {
  description = "Primary availability zone for resources"
  type        = string
  default     = "us-east-1a"
}

# =============================================================================
# COMPUTE CONFIGURATION
# =============================================================================

variable "instance_type" {
  description = "EC2 instance type for the web server"
  type        = string
  default     = "t2.micro"
}

variable "allowed_ssh_cidr" {
  description = "CIDR block allowed for SSH access (restrict in production!)"
  type        = string
  default     = "0.0.0.0/0"
}

variable "ssh_public_key_path" {
  description = "Path to your SSH public key file"
  type        = string
  default     = "~/.ssh/id_rsa.pub"
}

# =============================================================================
# E2E TESTING CONFIGURATION
# =============================================================================

variable "enable_e2e_infrastructure" {
  description = "Enable dedicated E2E testing infrastructure"
  type        = bool
  default     = false
}

variable "e2e_instance_type" {
  description = "Instance type for E2E test runners"
  type        = string
  default     = "t3.medium"
}

# =============================================================================
# PACKER AMI CONFIGURATION
# =============================================================================

variable "use_custom_ami" {
  description = "Use Packer-built custom AMIs instead of base Ubuntu with user_data"
  type        = bool
  default     = false
}

variable "web_server_ami_id" {
  description = "Custom AMI ID for web server (from Packer build)"
  type        = string
  default     = ""
}

variable "e2e_runner_ami_id" {
  description = "Custom AMI ID for E2E runner (from Packer build)"
  type        = string
  default     = ""
}
