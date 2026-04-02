# =============================================================================
# VARIABLES — Ephemeral Dev Environment (EC2 Free Tier)
# =============================================================================

variable "project_name" {
  description = "Project name used for resource naming and tagging"
  type        = string
  default     = "playwright-react-app"
}

variable "aws_region" {
  description = "AWS region for all resources"
  type        = string
  default     = "us-east-1"
}

variable "instance_type" {
  description = "EC2 instance type (t3.micro = Free Tier eligible)"
  type        = string
  default     = "t3.micro"
}

variable "repo_url" {
  description = "Git repository URL to clone and build on EC2"
  type        = string
  default     = ""
}

variable "commit_sha" {
  description = "Git commit SHA to checkout and build"
  type        = string
  default     = "main"
}
