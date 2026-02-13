# =============================================================================
# Packer Variables File
# =============================================================================
# Usage:
#   packer build -var-file=variables.pkrvars.hcl web-server.pkr.hcl
#   packer build -var-file=variables.pkrvars.hcl e2e-runner.pkr.hcl
# =============================================================================

aws_region   = "us-east-1"
node_version = "18"
