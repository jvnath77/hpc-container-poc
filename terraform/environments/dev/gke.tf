# ===========================================================================
# Phase 2 — Google Kubernetes Engine (GKE)
# ===========================================================================
#
# WHAT THIS CREATES:
#   1. A GKE Standard cluster (free zonal — no management fee!)
#   2. A GPU node pool with T4 GPUs on Spot VMs (~$0.11/hr per GPU)
#
# WHY GKE:
#   - Manages containers across machines automatically
#   - You say "run this on 2 GPUs" and K8s figures out where to put it
#   - Handles scheduling, scaling, restarting failed containers
#   - One free zonal cluster per billing account (saves ~$74/month vs EKS)
#
# WHY Spot VMs:
#   - ~70% cheaper than on-demand ($0.11/hr vs $0.35/hr for T4)
#   - GCP can reclaim them with 30s notice, but for a POC that's fine
#   - Autoscaling 0→4 means you pay $0 when no jobs are running

# ---------------------------------------------------------------------------
# GKE Cluster
# ---------------------------------------------------------------------------
# Standard mode (not Autopilot) gives us more control over node pools.
# Zonal cluster (single zone) qualifies for free tier — no management fee.


resource "google_container_cluster" "hpc_gke" {
  name     = "hpc-gke-poc"
  location = var.zone # Single zone = free tier (vs regional = $$$)

  network    = google_compute_network.hpc_vpc.name
  subnetwork = google_compute_subnetwork.hpc_subnet.name

  # We manage node pools separately (below), so remove the default pool
  # that GKE creates automatically. This is a common Terraform pattern.
  remove_default_node_pool = true
  initial_node_count       = 1 # Required but gets deleted immediately

  # Enable Workload Identity — lets pods authenticate to GCP services
  # using Kubernetes service accounts instead of JSON key files.
  # WHY: More secure, no keys to rotate or leak.



  workload_identity_config {
    workload_pool = "${var.project_id}.svc.id.goog"
  }

  # Logging and monitoring — sends data to Cloud Logging/Monitoring
  logging_service    = "logging.googleapis.com/kubernetes"
  monitoring_service = "monitoring.googleapis.com/kubernetes"

  # Deletion protection — prevents accidental deletion via Terraform
  # Set to false for POC so we can tear down easily
  deletion_protection = false

  depends_on = [
    google_project_service.required_apis # Wait for APIs to be enabled
  ]
}

# ---------------------------------------------------------------------------
# Default CPU Node Pool (for system pods)
# ---------------------------------------------------------------------------
# WHY: GKE needs at least one node pool for system components
# (kube-dns, metrics-server, etc.). These don't need GPUs.
# Using a small, cheap machine (e2-standard-2 = 2 vCPU, 8 GB RAM).

resource "google_container_node_pool" "default_pool" {
  name     = "default-pool"
  location = var.zone
  cluster  = google_container_cluster.hpc_gke.name

  node_count = 1 # Just 1 node for system pods

  node_config {
    machine_type = "e2-standard-2" # 2 vCPU, 8 GB — cheap, no GPU
    disk_size_gb = 50

    # Use the compute service account we created in Phase 1
    service_account = google_service_account.hpc_compute_sa.email
    oauth_scopes    = ["https://www.googleapis.com/auth/cloud-platform"]

    # Workload Identity for this node pool
    workload_metadata_config {
      mode = "GKE_METADATA"
    }
  }
}

# ---------------------------------------------------------------------------
# GPU Node Pool — T4 Spot VMs (autoscaling 0-4)
# ---------------------------------------------------------------------------
# WHY T4: Cheapest NVIDIA GPU on GCP ($0.11/hr Spot), 16GB VRAM, full CUDA
# WHY Spot: 70% cheaper. GCP can reclaim with 30s notice — fine for POC
# WHY autoscaling 0-4: Pay $0 when idle. Nodes spin up when you submit a GPU job

resource "google_container_node_pool" "gpu_t4_pool" {
  name     = "gpu-t4-pool"
  location = var.zone
  cluster  = google_container_cluster.hpc_gke.name

  # Start with 0 nodes — autoscaler adds them when GPU pods are pending
  node_count = 0

  autoscaling {
    min_node_count = 0 # Scale to zero when no GPU jobs running
    max_node_count = 4 # Max 4 GPU nodes ($0.44/hr if all running)
  }

  node_config {
    machine_type = "n1-standard-4" # 4 vCPU, 15 GB RAM — required for T4
    disk_size_gb = 100             # Larger disk for container images + datasets
    spot         = true            # Spot VM = ~70% cheaper!

    # Attach 1x NVIDIA T4 GPU to each node
    guest_accelerator {
      type  = "nvidia-tesla-t4"
      count = 1
      gpu_driver_installation_config {
        gpu_driver_version = "LATEST"
      }
    }

    # Use the compute service account
    service_account = google_service_account.hpc_compute_sa.email
    oauth_scopes    = ["https://www.googleapis.com/auth/cloud-platform"]

    # Workload Identity
    workload_metadata_config {
      mode = "GKE_METADATA"
    }

    # Labels — used for pod scheduling (nodeSelector)
    labels = {
      gpu-type = "nvidia-tesla-t4"
    }

    # Taint GPU nodes so ONLY GPU-requesting pods get scheduled here.
    # WHY: Without this, regular pods could land on expensive GPU nodes.
    # Pods must have a matching toleration + resource request for nvidia.com/gpu.
    taint {
      key    = "nvidia.com/gpu"
      value  = "present"
      effect = "NO_SCHEDULE"
    }
  }
}
