# =============================================================================
# PERFORMANCE ENVIRONMENT - OUTPUTS
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

output "api_url" {
  description = "API URL"
  value       = "http://${module.compute.public_ip}:3001"
}

output "ssh_command" {
  description = "SSH command"
  value       = module.compute.ssh_command
}

output "database_endpoint" {
  description = "RDS endpoint"
  value       = module.database.endpoint
}

output "database_secret_arn" {
  description = "Secrets Manager ARN for database credentials"
  value       = module.database.secret_arn
}

output "k6_env_vars" {
  description = "Environment variables for k6 tests"
  value       = <<-EOF
    export BASE_URL=http://${module.compute.public_ip}
    export API_URL=http://${module.compute.public_ip}:3001
  EOF
}

output "terraform_state_bucket" {
  description = "S3 bucket for Terraform state"
  value       = aws_s3_bucket.terraform_state.id
}
