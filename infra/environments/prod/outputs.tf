# =============================================================================
# PRODUCTION ENVIRONMENT - OUTPUTS
# =============================================================================

output "vpc_id" {
  description = "VPC ID"
  value       = module.networking.vpc_id
}

output "web_public_ip" {
  description = "Web server public IP"
  value       = module.compute.public_ip
}

output "web_url" {
  description = "Web server URL"
  value       = "http://${module.compute.public_ip}"
}

output "ssh_command" {
  description = "SSH command"
  value       = module.compute.ssh_command
}

output "terraform_state_bucket" {
  description = "S3 bucket for Terraform state"
  value       = aws_s3_bucket.terraform_state.id
}

output "database_endpoint" {
  description = "RDS endpoint"
  value       = var.enable_database ? module.database[0].endpoint : null
}

output "database_secret_arn" {
  description = "Secrets Manager ARN for database credentials"
  value       = var.enable_database ? module.database[0].secret_arn : null
}
