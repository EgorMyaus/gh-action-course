# =============================================================================
# VARIABLES — Ephemeral Dev Environment (GCE Free Tier)
# =============================================================================

variable "project_name" {
  description = "Project name used for resource naming and labeling"
  type        = string
  default     = "playwright-react-app"
}

variable "gcp_project_id" {
  description = "GCP project ID"
  type        = string
}

variable "gcp_region" {
  description = "GCP region (Free Tier: us-central1, us-east1, us-west1)"
  type        = string
  default     = "us-central1"
}

variable "gcp_zone" {
  description = "GCP zone for the compute instance"
  type        = string
  default     = "us-central1-a"
}

variable "machine_type" {
  description = "GCE machine type (e2-micro = Free Tier eligible)"
  type        = string
  default     = "e2-micro"
}
