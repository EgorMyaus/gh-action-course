# =============================================================================
# COMPUTE MODULE — VARIABLES
# =============================================================================

variable "name_prefix" {
  description = "Prefix applied to resource Name tags"
  type        = string
}

variable "common_tags" {
  description = "Tags merged into every resource in this module"
  type        = map(string)
  default     = {}
}

variable "vpc_id" {
  description = "ID of the VPC where the instance and security group will live"
  type        = string
}

variable "subnet_id" {
  description = "ID of the public subnet where the instance will launch"
  type        = string
}

variable "ami_id" {
  description = "AMI ID to boot from (caller decides — stock AL2023 lookup or Packer-built)"
  type        = string
}

variable "instance_type" {
  description = "EC2 instance type"
  type        = string
  default     = "t3.micro"
}

variable "user_data" {
  description = "User data script executed on first boot"
  type        = string
  default     = ""
}

variable "root_volume_size" {
  description = "Root EBS volume size in GB"
  type        = number
  default     = 30
}
