# ===========================================================================
# Phase 2 — Artifact Registry (Container Image Storage)
# ===========================================================================
#
# WHAT THIS CREATES:
#   A Docker repository in Artifact Registry for storing HPC container images
#
# WHY Artifact Registry (not Docker Hub):
#   - Private: only your project can access these images
#   - Fast: images are in the same region as your GKE cluster (us-central1)
#   - No rate limits: Docker Hub limits pulls to 100/6hr for free accounts
#   - Integrated: GKE nodes pull from AR automatically using their service account
#   - Vulnerability scanning: can scan images for known CVEs
#
# HOW TO USE:
#   # Build an image
#   docker build -t us-central1-docker.pkg.dev/hpc-container-poc/hpc-images/pytorch:latest .
#
#   # Push it
#   docker push us-central1-docker.pkg.dev/hpc-container-poc/hpc-images/pytorch:latest
#
#   # Use it in a K8s pod
#   image: us-central1-docker.pkg.dev/hpc-container-poc/hpc-images/pytorch:latest

resource "google_artifact_registry_repository" "hpc_images" {
  location      = var.region
  repository_id = "hpc-images"
  description   = "Docker images for HPC container workflows"
  format        = "DOCKER"

  # Cleanup policy — auto-delete untagged images older than 30 days
  # WHY: Prevents storage costs from growing as you push new images
  cleanup_policy_dry_run = false
  cleanup_policies {
    id     = "delete-untagged"
    action = "DELETE"
    condition {
      tag_state  = "UNTAGGED"
      older_than = "2592000s" # 30 days
    }
  }

  depends_on = [
    google_project_service.required_apis
  ]
}
