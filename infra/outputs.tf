# =============================================================================
# OUTPUT VALUES
# =============================================================================

# =============================================================================
# NETWORKING OUTPUTS
# =============================================================================

output "vpc_id" {
  description = "ID of the created VPC"
  value       = aws_vpc.main.id
}

output "public_subnet_id" {
  description = "ID of the public subnet"
  value       = aws_subnet.public.id
}

output "private_subnet_id" {
  description = "ID of the private subnet"
  value       = aws_subnet.private.id
}

# =============================================================================
# COMPUTE OUTPUTS
# =============================================================================

output "web_instance_id" {
  description = "ID of the web server EC2 instance"
  value       = aws_instance.web.id
}

output "web_public_ip" {
  description = "Public IP address of the web server"
  value       = aws_instance.web.public_ip
}

output "web_public_dns" {
  description = "Public DNS name of the web server"
  value       = aws_instance.web.public_dns
}

output "ssh_command" {
  description = "Command to SSH into the web server"
  value       = "ssh -i ~/.ssh/id_rsa ubuntu@${aws_instance.web.public_ip}"
}

output "web_url" {
  description = "URL to access the web server"
  value       = "http://${aws_instance.web.public_ip}"
}

# =============================================================================
# TERRAFORM STATE OUTPUTS
# =============================================================================

output "terraform_state_bucket" {
  description = "S3 bucket for Terraform state"
  value       = aws_s3_bucket.terraform_state.id
}

output "terraform_locks_table" {
  description = "DynamoDB table for Terraform state locking"
  value       = aws_dynamodb_table.terraform_locks.name
}

output "backend_config" {
  description = "Backend configuration to add to provider.tf"
  value       = <<-EOT
    
    # Add this to provider.tf after first apply:
    backend "s3" {
      bucket         = "${aws_s3_bucket.terraform_state.id}"
      key            = "infra/terraform.tfstate"
      region         = "${var.aws_region}"
      encrypt        = true
      dynamodb_table = "${aws_dynamodb_table.terraform_locks.name}"
    }
  EOT
}

# =============================================================================
# E2E TESTING OUTPUTS (Conditional)
# =============================================================================

output "e2e_runner_public_ip" {
  description = "Public IP of the E2E test runner (if enabled)"
  value       = var.enable_e2e_infrastructure ? aws_instance.e2e_runner[0].public_ip : null
}
