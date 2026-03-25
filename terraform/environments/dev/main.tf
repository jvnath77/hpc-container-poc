# Main Terraform configuration for Phase 1 — Foundation
#
# WHAT THIS CREATES:
#   1. A VPC (private network) — isolates our HPC cluster
#   2. A subnet in us-central1 — where our machines will live
#   3. Firewall rules — controls what traffic is allowed
#   4. IAP tunnel access — SSH without a bastion host (free!)
#   5. Service accounts — controls what each service can do
#
# WHY: Every GCP resource needs a network. Without this,
# machines can't talk to each other, and you can't SSH in.

terraform {
  required_version = ">= 1.5.0"

  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 5.0"
    }
  }
}

# ---------------------------------------------------------------------------
# Provider — tells Terraform to use GCP in us-central1
# ---------------------------------------------------------------------------
provider "google" {
  project = var.project_id
  region  = var.region
}

# ---------------------------------------------------------------------------
# VPC Network (Custom Mode)
# ---------------------------------------------------------------------------
# WHY custom mode: We want to control exactly which IP ranges our subnets use.
# "auto" mode creates subnets in every region, which is wasteful.
resource "google_compute_network" "hpc_vpc" {
  name                    = "hpc-vpc"
  auto_create_subnetworks = false # Custom mode — we define subnets ourselves
  description             = "VPC for HPC container POC"
}

# ---------------------------------------------------------------------------
# Subnet in us-central1
# ---------------------------------------------------------------------------
# WHY us-central1: Cheapest GPU pricing on GCP
# /20 gives us 4,094 usable IPs — plenty for a POC
resource "google_compute_subnetwork" "hpc_subnet" {
  name          = "hpc-subnet"
  network       = google_compute_network.hpc_vpc.id
  region        = var.region
  ip_cidr_range = "10.0.0.0/20"

  # Enable private Google access so VMs without public IPs
  # can still reach Google APIs (GCS, Artifact Registry, etc.)
  private_ip_google_access = true
}

# ---------------------------------------------------------------------------
# Firewall: Allow IAP SSH (replaces bastion host!)
# ---------------------------------------------------------------------------
# WHY: IAP (Identity-Aware Proxy) lets you SSH into VMs that have NO public IP.
# Google authenticates you through IAP, then tunnels SSH to the VM.
# Source range 35.235.240.0/20 is Google's IAP IP range.
# This is MORE secure than a bastion host and FREE.
resource "google_compute_firewall" "allow_iap_ssh" {
  name    = "allow-iap-ssh"
  network = google_compute_network.hpc_vpc.name

  allow {
    protocol = "tcp"
    ports    = ["22"]
  }

  # Google's IAP tunnel IP range — only Google's proxy can connect
  source_ranges = ["35.235.240.0/20"]
  description   = "Allow SSH via IAP tunnel (no bastion needed)"
}

# ---------------------------------------------------------------------------
# Firewall: Allow internal traffic within VPC
# ---------------------------------------------------------------------------
# WHY: Machines in our cluster need to talk to each other freely —
# SLURM controller ↔ compute nodes, NCCL GPU communication, NFS mounts, etc.
resource "google_compute_firewall" "allow_internal" {
  name    = "allow-internal"
  network = google_compute_network.hpc_vpc.name

  allow {
    protocol = "tcp"
    ports    = ["0-65535"]
  }

  allow {
    protocol = "udp"
    ports    = ["0-65535"]
  }

  allow {
    protocol = "icmp" # Ping — useful for debugging connectivity
  }

  # Only allow traffic from within our own subnet
  source_ranges = ["10.0.0.0/20"]
  description   = "Allow all internal traffic within HPC VPC"
}

# ---------------------------------------------------------------------------
# Service Account for Compute Nodes
# ---------------------------------------------------------------------------
# WHY: Instead of giving every VM your personal GCP credentials,
# we create a "service account" — a special identity for machines.
# It can read GCS buckets but can't delete your project.
resource "google_service_account" "hpc_compute_sa" {
  account_id   = "hpc-compute-sa"
  display_name = "HPC Compute Node Service Account"
  description  = "Used by GPU compute nodes to access GCS, Artifact Registry"
}

# Grant: read objects from GCS (datasets, container images)
resource "google_project_iam_member" "compute_sa_storage_viewer" {
  project = var.project_id
  role    = "roles/storage.objectViewer"
  member  = "serviceAccount:${google_service_account.hpc_compute_sa.email}"
}

# Grant: pull container images from Artifact Registry
resource "google_project_iam_member" "compute_sa_ar_reader" {
  project = var.project_id
  role    = "roles/artifactregistry.reader"
  member  = "serviceAccount:${google_service_account.hpc_compute_sa.email}"
}

# Grant: write logs to Cloud Logging (so we can debug jobs)
resource "google_project_iam_member" "compute_sa_log_writer" {
  project = var.project_id
  role    = "roles/logging.logWriter"
  member  = "serviceAccount:${google_service_account.hpc_compute_sa.email}"
}

# Grant: write metrics to Cloud Monitoring (GPU utilization, etc.)
resource "google_project_iam_member" "compute_sa_metric_writer" {
  project = var.project_id
  role    = "roles/monitoring.metricWriter"
  member  = "serviceAccount:${google_service_account.hpc_compute_sa.email}"
}

# ---------------------------------------------------------------------------
# Service Account for Terraform (used by GitHub Actions)
# ---------------------------------------------------------------------------
# WHY: GitHub Actions needs a service account to create/manage GCP resources.
# This SA has broad permissions because it IS the infrastructure manager.
resource "google_service_account" "terraform_sa" {
  account_id   = "terraform-ci"
  display_name = "Terraform CI/CD Service Account"
  description  = "Used by GitHub Actions to run Terraform plan/apply"
}

# Grant: Editor role (can create/modify most resources)
resource "google_project_iam_member" "terraform_sa_editor" {
  project = var.project_id
  role    = "roles/editor"
  member  = "serviceAccount:${google_service_account.terraform_sa.email}"
}

# ---------------------------------------------------------------------------
# Enable Required GCP APIs
# ---------------------------------------------------------------------------
# WHY: GCP requires you to explicitly enable each API before using it.
# Without this, Terraform would fail when trying to create GKE clusters,
# Artifact Registry repos, etc.
resource "google_project_service" "required_apis" {
  for_each = toset([
    "compute.googleapis.com",              # GCE — virtual machines
    "container.googleapis.com",            # GKE — Kubernetes
    "artifactregistry.googleapis.com",     # Container image storage
    "cloudbuild.googleapis.com",           # CI/CD builds
    "monitoring.googleapis.com",           # Cloud Monitoring
    "logging.googleapis.com",              # Cloud Logging
    "iap.googleapis.com",                  # IAP tunnel for SSH
    "iam.googleapis.com",                  # IAM API
    "cloudresourcemanager.googleapis.com", # Project-level operations
  ])

  project                    = var.project_id
  service                    = each.value
  disable_dependent_services = false
  disable_on_destroy         = false
}
