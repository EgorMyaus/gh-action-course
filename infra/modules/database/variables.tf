# =============================================================================
# DATABASE MODULE - VARIABLES
# =============================================================================

variable "name_prefix" {
  type = string
}

variable "common_tags" {
  type    = map(string)
  default = {}
}

variable "vpc_id" {
  type = string
}

variable "private_subnet_ids" {
  type = list(string)
}

variable "web_security_group_id" {
  type = string
}

variable "db_name" {
  type    = string
  default = "reactapp"
}

variable "db_username" {
  type    = string
  default = "dbadmin"
}

variable "instance_class" {
  type    = string
  default = "db.t3.micro"
}

variable "multi_az" {
  type    = bool
  default = false
}

variable "backup_retention" {
  type    = number
  default = 7
}
