# Input variables — these are the knobs you can turn
#
# WHY variables: Instead of hardcoding "hpc-container-poc" everywhere,
# we use variables so the same code works for different projects/regions.

variable "project_id" {
  description = "GCP project ID where all resources will be created"
  type        = string
}

variable "region" {
  description = "GCP region — us-central1 is cheapest for GPUs"
  type        = string
  default     = "us-central1"
}

variable "zone" {
  description = "GCP zone within the region"
  type        = string
  default     = "us-central1-a"
}
