# =============================================================================
# COMPUTE MODULE — OUTPUTS
# =============================================================================

output "instance_id" {
  description = "EC2 instance ID"
  value       = aws_instance.app.id
}

output "public_ip" {
  description = "Public IP address of the EC2 instance"
  value       = aws_instance.app.public_ip
}

output "security_group_id" {
  description = "ID of the app security group"
  value       = aws_security_group.app.id
}
