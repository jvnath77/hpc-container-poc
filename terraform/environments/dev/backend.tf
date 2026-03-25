# Stores Terraform state in a GCS bucket so it's not lost
# and multiple people / CI can access the same state
#
# WHY: Without this, Terraform state lives on your laptop.
# If you run Terraform from GitHub Actions AND locally,
# they'd have different views of what exists. GCS fixes that.
#
# NOTE: You must create this bucket ONCE manually before running Terraform:
#   gsutil mb -l us-central1 gs://hpc-container-poc-tfstate
terraform {
  backend "gcs" {
    bucket = "hpc-container-poc-tfstate"
    prefix = "dev"
  }
}
