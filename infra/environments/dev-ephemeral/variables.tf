# =============================================================================
# VARIABLES — Ephemeral Dev Environment (EC2 Free Tier)
# =============================================================================
# Variable declarations only — values live in terraform.tfvars
# =============================================================================

variable "project_name" {
  description = "Project name used for resource naming and tagging"
  type        = string
}

variable "aws_region" {
  description = "AWS region for all resources"
  type        = string
}

variable "instance_type" {
  description = "EC2 instance type (t3.micro = Free Tier eligible)"
  type        = string
}

variable "github_repo" {
  description = "GitHub repository in owner/repo format (for OIDC trust policy, future use)"
  type        = string
}

variable "custom_ami_id" {
  description = "Custom Packer-built AMI ID. When set, skips the stock AL2023 lookup and uses this AMI instead."
  type        = string
  default     = ""
}

