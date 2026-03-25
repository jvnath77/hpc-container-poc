# Setting Up GitHub Actions ↔ GCP Authentication

> **One-time setup.** After this, every `git push` triggers Terraform automatically.

## How It Works

```
GitHub Actions (runs your code)
        │
        │ "I am github.com/jvnath77/hpc-container-poc"
        ▼
Workload Identity Federation (GCP verifies GitHub's identity)
        │
        │ "Okay, you're allowed to act as terraform-ci@..."
        ▼
GCP Service Account (terraform-ci)
        │
        │ Has Editor permissions
        ▼
Creates/modifies GCP resources (VPC, GKE, etc.)
```

**Why Workload Identity Federation?**
- No JSON key files to leak or rotate
- GitHub proves its identity using OIDC tokens (like a passport)
- GCP trusts GitHub's identity provider directly
- More secure than storing a service account key as a GitHub secret

## Prerequisites

1. GCP account with a project (or free trial)
2. `gcloud` CLI installed: `brew install --cask google-cloud-sdk`
3. You are the project owner

## Step-by-Step

### 1. Login to GCP and set your project

```bash
gcloud auth login
gcloud config set project hpc-container-poc
```

### 2. Create the Terraform state bucket (one time only)

```bash
gsutil mb -l us-central1 gs://hpc-container-poc-tfstate
```

### 3. Create the Terraform service account

```bash
# Create the service account
gcloud iam service-accounts create terraform-ci \
  --display-name="Terraform CI/CD Service Account"

# Grant it Editor role
gcloud projects add-iam-policy-binding hpc-container-poc \
  --member="serviceAccount:terraform-ci@hpc-container-poc.iam.gserviceaccount.com" \
  --role="roles/editor"
```

### 4. Set up Workload Identity Federation

```bash
# Get your project number (not the same as project ID)
PROJECT_NUMBER=$(gcloud projects describe hpc-container-poc --format='value(projectNumber)')

# Create a Workload Identity Pool (a container for identity providers)
gcloud iam workload-identity-pools create "github-pool" \
  --project="hpc-container-poc" \
  --location="global" \
  --display-name="GitHub Actions Pool"

# Create a Provider within the pool (tells GCP to trust GitHub)
gcloud iam workload-identity-pools providers create-oidc "github-provider" \
  --project="hpc-container-poc" \
  --location="global" \
  --workload-identity-pool="github-pool" \
  --display-name="GitHub Provider" \
  --attribute-mapping="google.subject=assertion.sub,attribute.repository=assertion.repository" \
  --issuer-uri="https://token.actions.githubusercontent.com"

# Allow GitHub Actions from YOUR repo to impersonate the Terraform SA
gcloud iam service-accounts add-iam-policy-binding \
  "terraform-ci@hpc-container-poc.iam.gserviceaccount.com" \
  --project="hpc-container-poc" \
  --role="roles/iam.workloadIdentityUser" \
  --member="principalSet://iam.googleapis.com/projects/${PROJECT_NUMBER}/locations/global/workloadIdentityPools/github-pool/attribute.repository/jvnath77/hpc-container-poc"
```

### 5. Add secrets to GitHub

Go to your repo: **Settings → Secrets and variables → Actions → New repository secret**

| Secret Name | Value |
|-------------|-------|
| `WIF_PROVIDER` | `projects/PROJECT_NUMBER/locations/global/workloadIdentityPools/github-pool/providers/github-provider` |
| `GCP_SERVICE_ACCOUNT` | `terraform-ci@hpc-container-poc.iam.gserviceaccount.com` |

> Replace `PROJECT_NUMBER` with the actual number from step 4.
> Find it with: `gcloud projects describe hpc-container-poc --format='value(projectNumber)'`

### 6. Test it!

```bash
# Create a branch, make a change, push, and open a PR
git checkout -b test-terraform
echo "# test" >> terraform/environments/dev/main.tf
git add . && git commit -m "Test GitHub Actions"
git push -u origin test-terraform
# Open a PR on GitHub → Actions tab should show "Terraform Plan" running
```

## Workflow Summary

| Event | Workflow | What Happens |
|-------|----------|-------------|
| PR opened/updated | `terraform-plan.yml` | Runs `terraform plan`, posts result as PR comment |
| PR merged to main | `terraform-apply.yml` | Runs `terraform apply`, creates real GCP resources |
