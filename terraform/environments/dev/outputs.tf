# Outputs — values printed after terraform apply
# Useful for getting IDs/names of created resources

output "vpc_name" {
  description = "Name of the VPC network"
  value       = google_compute_network.hpc_vpc.name
}

output "subnet_name" {
  description = "Name of the subnet"
  value       = google_compute_subnetwork.hpc_subnet.name
}

output "compute_sa_email" {
  description = "Email of the compute node service account"
  value       = google_service_account.hpc_compute_sa.email
}

# Phase 2 outputs
output "gke_cluster_name" {
  description = "Name of the GKE cluster"
  value       = google_container_cluster.hpc_gke.name
}

output "gke_cluster_endpoint" {
  description = "GKE cluster API endpoint"
  value       = google_container_cluster.hpc_gke.endpoint
  sensitive   = true
}

output "artifact_registry_url" {
  description = "URL for pushing/pulling container images"
  value       = "${var.region}-docker.pkg.dev/${var.project_id}/${google_artifact_registry_repository.hpc_images.repository_id}"
}

