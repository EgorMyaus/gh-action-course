# =============================================================================
# NETWORKING MODULE — VARIABLES
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

variable "vpc_cidr" {
  description = "CIDR block for the VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "public_subnet_cidr" {
  description = "CIDR block for the single public subnet"
  type        = string
  default     = "10.0.1.0/24"
}

variable "availability_zone" {
  description = "Availability zone for the public subnet"
  type        = string
}
