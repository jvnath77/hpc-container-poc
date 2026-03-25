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

output "terraform_sa_email" {
  description = "Email of the Terraform CI/CD service account"
  value       = google_service_account.terraform_sa.email
}
