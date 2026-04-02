# =============================================================================
# OUTPUTS — Ephemeral Dev Environment (EC2 Free Tier)
# =============================================================================

output "app_url" {
  description = "URL of the React application (EC2 public IP)"
  value       = "http://${aws_instance.app.public_ip}"
}

output "instance_id" {
  description = "EC2 instance ID"
  value       = aws_instance.app.id
}

output "instance_public_ip" {
  description = "EC2 instance public IP"
  value       = aws_instance.app.public_ip
}
