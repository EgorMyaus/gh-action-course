# =============================================================================
# REPORTPORTAL ENVIRONMENT - OUTPUTS
# =============================================================================

output "vpc_id" {
  description = "VPC ID"
  value       = aws_vpc.reportportal.id
}

output "public_ip" {
  description = "ReportPortal server public IP"
  value       = aws_eip.reportportal.public_ip
}

output "reportportal_url" {
  description = "ReportPortal UI URL"
  value       = "http://${aws_eip.reportportal.public_ip}:8080"
}

output "traefik_url" {
  description = "Traefik Dashboard URL"
  value       = "http://${aws_eip.reportportal.public_ip}:8081"
}

output "ssh_command" {
  description = "SSH command to connect"
  value       = "ssh -i ~/.ssh/id_rsa ubuntu@${aws_eip.reportportal.public_ip}"
}

output "setup_commands" {
  description = "Commands to run after SSH"
  value       = <<-EOF

    # 1. SSH into server
    ssh -i ~/.ssh/id_rsa ubuntu@${aws_eip.reportportal.public_ip}

    # 2. Clone your repo or copy docker-compose.yml
    mkdir -p /opt/reportportal
    cd /opt/reportportal

    # 3. Copy docker-compose.yml (from your local machine)
    # scp reportportal/docker-compose.yml ubuntu@${aws_eip.reportportal.public_ip}:/opt/reportportal/

    # 4. Start ReportPortal
    docker compose up -d

    # 5. Access UI
    # URL: http://${aws_eip.reportportal.public_ip}:8080
    # Login: superadmin / erebus

  EOF
}

output "ci_environment_variables" {
  description = "Environment variables for CI/CD"
  value       = <<-EOF
    RP_ENDPOINT=http://${aws_eip.reportportal.public_ip}:8080/api/v1
    RP_PROJECT=default_personal
  EOF
}

output "terraform_state_bucket" {
  description = "S3 bucket for Terraform state"
  value       = aws_s3_bucket.terraform_state.id
}

output "instance_id" {
  description = "EC2 instance ID"
  value       = aws_instance.reportportal.id
}

output "security_group_id" {
  description = "Security group ID"
  value       = aws_security_group.reportportal.id
}
