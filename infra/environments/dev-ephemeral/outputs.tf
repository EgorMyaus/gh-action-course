# =============================================================================
# OUTPUTS — Ephemeral Dev Environment (EC2 Free Tier)
# =============================================================================

output "app_url" {
  description = "URL of the React application (EC2 public IP)"
  value       = "http://${module.compute.public_ip}"
}

output "instance_id" {
  description = "EC2 instance ID"
  value       = module.compute.instance_id
}

output "instance_public_ip" {
  description = "EC2 instance public IP"
  value       = module.compute.public_ip
}
