# =============================================================================
# OUTPUTS — Ephemeral Dev Environment (GCE Free Tier)
# =============================================================================

output "app_url" {
  description = "URL of the React application (GCE external IP)"
  value       = "http://${google_compute_instance.app.network_interface[0].access_config[0].nat_ip}"
}

output "instance_name" {
  description = "GCE instance name"
  value       = google_compute_instance.app.name
}

output "instance_zone" {
  description = "GCE instance zone"
  value       = google_compute_instance.app.zone
}

output "instance_public_ip" {
  description = "GCE instance external IP"
  value       = google_compute_instance.app.network_interface[0].access_config[0].nat_ip
}
