# =============================================================================
# EPHEMERAL DEV ENVIRONMENT — GCE + Docker (Free Tier)
# =============================================================================
# Spins up a single e2-micro GCE instance with Docker for E2E testing.
# Designed to be created and destroyed per CI run (GitLab CI).
# Cost: $0 (within GCP Free Tier — 1 e2-micro/month in us-central1/us-east1/us-west1)
#
# Usage:
#   terraform init
#   terraform apply -auto-approve
#   # ... run tests against the GCE external IP ...
#   terraform destroy -auto-approve
# =============================================================================

terraform {
  required_version = ">=1.7"

  # ===========================================================================
  # TERRAFORM CLOUD — Free Tier (Remote State + Locking)
  # ===========================================================================
  # Prerequisites:
  #   1. Create a free Terraform Cloud account at https://app.terraform.io
  #   2. Create an organization (or use an existing one)
  #   3. Create a workspace named "playwright-react-app-dev-ephemeral-gcp"
  #      → Settings > General > Execution Mode = "Local"
  #        (runs on the GitLab runner, TF Cloud only stores state)
  #   4. Generate a Team or User API token:
  #      → Settings > Teams > API Token (or User Settings > Tokens)
  #   5. Add the token as GitLab CI/CD variable: TF_API_TOKEN
  #   6. Set GitLab CI/CD variable: TF_CLOUD_ORGANIZATION = "<your-org>"
  # ===========================================================================
  cloud {
    # Organization is set via TF_CLOUD_ORGANIZATION env var in the pipeline

    workspaces {
      name = "playwright-react-app-dev-ephemeral-gcp"
    }
  }

  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~>5.0"
    }
  }
}

provider "google" {
  project = var.gcp_project_id
  region  = var.gcp_region
  zone    = var.gcp_zone

  default_labels = {
    environment = "dev-ephemeral"
    managed-by  = "terraform"
    project     = var.project_name
    ttl         = "1h"
    owner       = "gitlab-ci"
  }
}

locals {
  name_prefix = "${var.project_name}-dev"
}

# =============================================================================
# NETWORKING — VPC, Subnet, Router (minimal)
# =============================================================================

resource "google_compute_network" "main" {
  name                    = "${local.name_prefix}-vpc"
  auto_create_subnetworks = false
}

resource "google_compute_subnetwork" "public" {
  name          = "${local.name_prefix}-public"
  ip_cidr_range = "10.0.1.0/24"
  region        = var.gcp_region
  network       = google_compute_network.main.id
}

# =============================================================================
# FIREWALL RULES — HTTP + SSH
# =============================================================================

resource "google_compute_firewall" "allow_http" {
  name    = "${local.name_prefix}-allow-http"
  network = google_compute_network.main.name

  allow {
    protocol = "tcp"
    ports    = ["80"]
  }

  source_ranges = ["0.0.0.0/0"]
  target_tags   = ["web-server"]
}

resource "google_compute_firewall" "allow_ssh" {
  name    = "${local.name_prefix}-allow-ssh"
  network = google_compute_network.main.name

  allow {
    protocol = "tcp"
    ports    = ["22"]
  }

  # IAP SSH range (35.235.240.0/20) for gcloud compute ssh
  # Plus 0.0.0.0/0 for direct SSH from CI runners
  source_ranges = ["0.0.0.0/0"]
  target_tags   = ["web-server"]
}

# =============================================================================
# GCE INSTANCE — e2-micro (Free Tier) + Docker
# =============================================================================

resource "google_compute_instance" "app" {
  name         = "${local.name_prefix}-app"
  machine_type = var.machine_type
  zone         = var.gcp_zone

  tags = ["web-server"]

  boot_disk {
    initialize_params {
      image = "debian-cloud/debian-12"
      size  = 30
      type  = "pd-standard"
    }
  }

  network_interface {
    subnetwork = google_compute_subnetwork.public.id

    access_config {
      # Ephemeral external IP
    }
  }

  metadata_startup_script = <<-EOF
#!/bin/bash
exec > /var/log/startup-script.log 2>&1
set -ex

# Install Docker (official method for Debian 12)
apt-get update -y
apt-get install -y ca-certificates curl gnupg
install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/debian/gpg \
  | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
chmod a+r /etc/apt/keyrings/docker.gpg
echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] \
  https://download.docker.com/linux/debian $(. /etc/os-release && echo "$VERSION_CODENAME") stable" \
  > /etc/apt/sources.list.d/docker.list
apt-get update -y
apt-get install -y docker-ce docker-ce-cli containerd.io
systemctl start docker
systemctl enable docker

# Signal that Docker is ready
touch /tmp/docker-ready
EOF

  labels = {
    environment = "dev-ephemeral"
    managed-by  = "terraform"
    project     = var.project_name
    ttl         = "1h"
    owner       = "gitlab-ci"
  }

  # Allow Terraform to replace the instance if startup script changes
  allow_stopping_for_update = true
}
