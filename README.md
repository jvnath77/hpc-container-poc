# HPC Container-Driven Workflow POC Plan (GCP)

> **Status:** Draft for Review — DO NOT IMPLEMENT YET
> **Cloud Platform:** Google Cloud Platform (GCP)
> **Region:** us-central1 (Iowa — cheapest GPU pricing)
> **Team:** Solo developer
> **Budget:** Ultra-budget (~$285 total)
> **GPU:** n1-standard-4 + 1× T4 (16GB, Spot VMs) — cheapest NVIDIA GPU on GCP
> **Free Credits:** $300 for new GCP accounts (90-day trial)
> **Purpose:** Phased plan to design and implement a next-generation HPC environment leveraging container-driven workflows for GPU-accelerated research.
> **Last Updated:** March 24, 2026

---

## 🧑‍🎓 New Here? Start With This Section

If you're new to HPC, containers, or GPU computing, this section explains **what each technology is, why we need it, and how it fits together** before diving into the phases.

### What Is HPC (High-Performance Computing)?

**In simple terms:** HPC is about using many powerful computers (called "nodes") working together to solve big problems — like training an AI model on millions of images, or simulating weather patterns.

**Why we need it:** A single laptop or server isn't fast enough. We need multiple machines, each with powerful GPUs, connected by fast networks, sharing the same data.

**Real-world analogy:** Think of HPC like a restaurant kitchen. One chef (your laptop) can make one dish at a time. An HPC cluster is a kitchen with 50 chefs (compute nodes), each with specialized tools (GPUs), sharing the same pantry (storage), coordinated by a head chef (job scheduler).

### What Are Containers? Why Do We Need Them?

**In simple terms:** A container is a lightweight, portable package that bundles your code + all its dependencies (libraries, CUDA drivers, Python version, etc.) into one unit that runs the same everywhere.

**Why we need them:**
- 🔥 **"It works on my machine" problem** — Without containers, researchers spend days installing the right CUDA version, PyTorch version, etc. on the cluster. Containers eliminate this.
- 📦 **Reproducibility** — A container built today will produce the same results 2 years from now.
- 🚀 **Portability** — Same container runs on your laptop, the HPC cluster, and GCP.

**Key tools:**
| Tool | What It Does |
|------|-------------|
| **Docker** | Most popular container tool. Builds and runs containers. Needs root access. |
| **Enroot** | NVIDIA's container tool for HPC. Doesn't need root (important for shared clusters). |
| **Apptainer/Singularity** | Another rootless container tool popular in HPC/academia. |

### What Is Kubernetes (K8s)? Why Do We Need It?

**In simple terms:** Kubernetes is a system that automatically manages containers across many servers. You tell it "I need 4 GPUs to run this container" and it figures out where to put it.

**Why we need it:**
- Without K8s, you'd have to SSH into each server and manually start containers.
- K8s handles: scheduling, scaling, restarting failed containers, networking between containers, and resource limits.

**GCP equivalent:** **Google Kubernetes Engine (GKE)** — GCP's managed Kubernetes. GKE Autopilot even handles the node management for you — you just submit pods.

### What Is SLURM? Why Do We Need It?

**In simple terms:** SLURM is a job scheduler — the "traffic controller" of an HPC cluster. Users submit jobs ("train my model for 8 hours using 4 GPUs") and SLURM queues them, assigns resources, and runs them in order.

**Why we need it:**
- If 10 researchers each want 8 GPUs but you only have 32 GPUs total, SLURM manages the queue fairly.
- It handles: job queuing, priority, time limits, GPU allocation, multi-node coordination.

**GCP equivalent:** **Cloud HPC Toolkit** (formerly HPC Toolkit) — Google's open-source tool to deploy SLURM clusters on GCP. One YAML config → full SLURM cluster with auto-scaling GPU nodes.

### What Is a GPU and Why Is It Special?

**In simple terms:** A GPU (Graphics Processing Unit) was originally for rendering video games, but it turns out GPUs are incredible at the math needed for AI/ML. A single GPU can do thousands of calculations in parallel.

**Key GPUs on GCP:**

| GPU | Memory | Use Case | GCP Machine Type | On-Demand (per GPU) | Spot (approx) |
|-----|--------|----------|-----------------|--------------------|----|
| **T4** | 16 GB | POC/dev/test, validation | n1-standard-4 + T4 | ~$0.35/hr | **~$0.11/hr** |
| **L4** | 24 GB | Dev/test, inference, small training | g2-standard-4 | ~$0.65/hr (incl. VM) | ~$0.20/hr |
| **A100 40GB** | 40 GB | Production training | a2-highgpu-1g | ~$3.67/hr | ~$1.10/hr |
| **A100 80GB** | 80 GB | Large model training | a2-ultragpu-1g | ~$5.07/hr | ~$1.52/hr |
| **H100** | 80 GB | Cutting-edge, large models | a3-highgpu-8g | ~$25/hr (8 GPUs) | ~$7.50/hr |

> 💡 **For this POC, we'll use T4 GPUs on Spot VMs** — at ~$0.11/hr per GPU, it's the cheapest NVIDIA GPU on GCP. T4 has 16GB memory and full CUDA support — more than enough to validate all infrastructure patterns. Upgrade to L4/A100 later for real workloads.

### What Is NCCL?

**In simple terms:** NCCL (pronounced "nickel") is NVIDIA's library that lets GPUs talk to each other efficiently. When you train a model across 8 GPUs (or 8 GPUs × 4 machines = 32 GPUs), they need to constantly share calculations. NCCL handles that.

### What Is gVNIC?

**In simple terms:** gVNIC (Google Virtual NIC) is GCP's high-performance virtual network interface — faster than the default virtio-net. For HPC, it offers higher bandwidth (up to 100 Gbps on some instance types). It's similar to AWS's EFA but built into GCP's network stack.

### What Is Terraform? What Is Ansible?

| Tool | What It Does | Analogy |
|------|-------------|---------|
| **Terraform** | Creates infrastructure (VPC, GCE instances, GKE clusters, GCS buckets) from code files. You write a `.tf` file, run `terraform apply`, and it builds everything on GCP. | It's like a blueprint — describes WHAT to build. |
| **Ansible** | Configures servers after they're created (install packages, configure SLURM, set up monitoring). Connects via SSH, runs tasks in order. | It's like an instruction manual — describes HOW to set up what's already built. |

**Why both?** Terraform creates the GCP resources. Ansible configures what's running on them.

### What Is CI/CD?

**In simple terms:** CI/CD (Continuous Integration / Continuous Deployment) automatically builds, tests, and deploys your code every time you push to Git.

**For this POC:** Every time someone updates a container image recipe (Dockerfile), CI/CD will automatically rebuild the image, scan it for security issues, and push it to the container registry.

**Tools:** **GitHub Actions** (free for public repos) or **Cloud Build** (120 free build-minutes/day on GCP).

### How Does It All Fit Together?

```
┌──────────────────────────────────────────────────────────────────────┐
│                        THE BIG PICTURE (GCP)                         │
│                                                                      │
│   Researcher writes code                                             │
│        │                                                             │
│        ▼                                                             │
│   Code is packaged into a CONTAINER (Docker/Enroot)                  │
│        │                                                             │
│        ▼                                                             │
│   Container image is stored in ARTIFACT REGISTRY (GAR)               │
│        │                                                             │
│        ├──────────────────────┐                                      │
│        ▼                     ▼                                       │
│   SLURM (Cloud HPC Toolkit) OR   KUBERNETES (GKE)                   │
│   "Give me 4 GPUs for          "Run 4 replicas of this              │
│    8 hours to train"            container with 1 GPU each"           │
│        │                     │                                       │
│        ▼                     ▼                                       │
│   GPU COMPUTE NODES (GCE VMs with NVIDIA T4 GPUs, Spot pricing)     │
│        │                                                             │
│        ▼                                                             │
│   Data read from STORAGE (GCS / Filestore / Parallelstore)          │
│        │                                                             │
│        ▼                                                             │
│   Results/checkpoints saved back to STORAGE                          │
│        │                                                             │
│        ▼                                                             │
│   MONITORING (Cloud Monitoring + Grafana) tracks GPU usage, jobs     │
│        │                                                             │
│        ▼                                                             │
│   All built by TERRAFORM + ANSIBLE (Infrastructure-as-Code)          │
│   and updated automatically by CI/CD (GitHub Actions / Cloud Build)  │
└──────────────────────────────────────────────────────────────────────┘
```

---

## GCP vs AWS: Key Service Mapping

> If you've read the AWS plan, here's how everything maps over:

| Concept | AWS Service | GCP Service |
|---------|-------------|-------------|
| Managed Kubernetes | EKS | **GKE** (free Autopilot/Zonal cluster!) |
| HPC SLURM cluster | ParallelCluster | **Cloud HPC Toolkit** (open-source) |
| Container registry | ECR | **Artifact Registry** |
| Object storage | S3 | **Cloud Storage (GCS)** |
| High-perf filesystem | FSx for Lustre | **Filestore** (NFS) / **Parallelstore** (Lustre-like) |
| POSIX mount for object storage | Mountpoint for S3 | **Cloud Storage FUSE** (gcsfuse) |
| GPU instances | g4dn.xlarge (T4) | **n1-standard-4 + T4** |
| HPC networking | EFA | **gVNIC** / **GPUDirect-TCPXO** |
| IaC | Terraform (AWS provider) | **Terraform (Google provider)** |
| Managed Prometheus | Amazon Managed Prometheus | **Google Managed Prometheus (GMP)** — free with GKE! |
| CI/CD | GitHub Actions | **GitHub Actions** or **Cloud Build** (120 free min/day) |
| IAM | AWS IAM | **GCP IAM + Service Accounts** |
| Budget alerts | AWS Budgets | **GCP Budget Alerts** |
| Machine images | AMI (Packer) | **Custom Images** (Packer) |
| SSH bastion | EC2 bastion | **IAP Tunnel** (no bastion needed — free!) |

### 🎯 GCP Advantages for This POC

1. **$300 free credits** (vs AWS $200) — covers the entire POC!
2. **GKE free tier** — one Autopilot or Zonal cluster per billing account at no management fee
3. **IAP Tunnel** — SSH into VMs without a bastion host (saves money + more secure)
4. **Cloud Storage FUSE** — same concept as Mountpoint for S3, built-in and free
5. **Google Managed Prometheus** — included free with GKE, no setup needed
6. **Cloud Build** — 120 free build-minutes/day
7. **T4 Spot VMs ~$0.11/hr** — cheaper than AWS g4dn.xlarge spot ($0.16/hr)
8. **Cloud Shell** — free terminal with 5GB persistent disk, pre-installed gcloud/kubectl/terraform

---

## Table of Contents

0. [New Here? Start With This Section](#-new-here-start-with-this-section)
1. [Phase 1 — Foundation & Infrastructure Baseline](#phase-1--foundation--infrastructure-baseline)
2. [Phase 2 — Container Platform Setup & GPU Enablement](#phase-2--container-platform-setup--gpu-enablement)
3. [Phase 3 — HPC Scheduler Integration (SLURM on GCP)](#phase-3--hpc-scheduler-integration-slurm-on-gcp)
4. [Phase 4 — Job Templates for Batch & Distributed Workloads](#phase-4--job-templates-for-batch--distributed-workloads)
5. [Phase 5 — Distributed ML Framework Integration](#phase-5--distributed-ml-framework-integration)
6. [Phase 6 — Storage Integration](#phase-6--storage-integration)
7. [Phase 7 — Workflow Orchestration Evaluation & Integration](#phase-7--workflow-orchestration-evaluation--integration)
8. [Phase 8 — Monitoring, Benchmarking & Performance Tuning](#phase-8--monitoring-benchmarking--performance-tuning)
9. [Phase 9 — CI/CD, IaC & Automation](#phase-9--cicd-iac--automation)
10. [Phase 10 — Auto-Scaling & Production Readiness](#phase-10--auto-scaling--production-readiness)
11. [Summary & Timeline](#summary-phase-timeline-suggested)
12. [Estimated GCP Cost](#-estimated-gcp-cost-for-full-poc)
13. [Tech Stack Summary](#tech-stack-summary-gcp-specific)
14. [Prerequisites](#prerequisites-what-you-need-before-starting)
15. [Open Questions & Decisions](#decisions-made-)

---

## Phase 1 — Foundation & Infrastructure Baseline

> **🧑‍🎓 Why this phase?** Before running any GPU jobs, we need a solid foundation — a VPC (private network on GCP), proper IAM roles (who can do what), and base machine images. Think of this as laying the foundation before building a house.

**Goal:** Set up GCP networking, security, and base machine images that all subsequent phases build upon.

### What to Do
- Create a GCP Project (all resources live inside a project)
- Create a VPC network with subnets in us-central1
- Configure IAM roles and service accounts (who can create instances, access GCS, etc.)
- Build a custom VM image with Packer — pre-configured with NVIDIA drivers, CUDA, and basic tools
- Set up Ansible playbooks for server configuration
- Configure IAP (Identity-Aware Proxy) for SSH — no bastion host needed!
- Enable required GCP APIs
- Document the architecture and networking layout

### How to Do It

| Step | GCP Service / Tool | Why We Need It |
|------|-------------------|----------------|
| Project | **GCP Project** | Logical container for all resources, billing, and permissions |
| Private network | **VPC + Subnets** | Isolate our HPC cluster; control traffic flow |
| Server access | **IAP Tunnel** | SSH into any VM securely without a public IP or bastion host — **free!** |
| Machine image | **Packer → Custom Image** | Pre-bake NVIDIA drivers, CUDA, Docker, Enroot into an image so every new node is ready instantly |
| Server config | **Ansible** | Automate package installs, kernel tuning, user setup on every node |
| Permissions | **IAM + Service Accounts** | Control what each service can access (e.g., compute nodes can read GCS but not delete it) |
| Infrastructure code | **Terraform** | Define all of the above in code files so it's repeatable and version-controlled |

### Key Commands

```bash
# 1. Create a new GCP project (or use an existing one)
gcloud projects create hpc-container-poc --name="HPC Container POC"
gcloud config set project hpc-container-poc

# 2. Enable required APIs
gcloud services enable compute.googleapis.com \
  container.googleapis.com \
  artifactregistry.googleapis.com \
  cloudbuild.googleapis.com \
  monitoring.googleapis.com \
  logging.googleapis.com \
  iap.googleapis.com

# 3. Create VPC network (custom mode — we control the subnets)
gcloud compute networks create hpc-vpc --subnet-mode=custom

# 4. Create subnet in us-central1
gcloud compute networks subnets create hpc-subnet \
  --network=hpc-vpc \
  --region=us-central1 \
  --range=10.0.0.0/20

# 5. Allow IAP SSH access (no bastion needed!)
gcloud compute firewall-rules create allow-iap-ssh \
  --network=hpc-vpc \
  --allow=tcp:22 \
  --source-ranges=35.235.240.0/20  # Google's IAP IP range

# 6. Create a service account for compute nodes
gcloud iam service-accounts create hpc-compute-sa \
  --display-name="HPC Compute Node SA"

# Grant it access to read GCS buckets
gcloud projects add-iam-policy-binding hpc-container-poc \
  --member="serviceAccount:hpc-compute-sa@hpc-container-poc.iam.gserviceaccount.com" \
  --role="roles/storage.objectViewer"

# 7. SSH via IAP tunnel (replaces bastion host!)
gcloud compute ssh my-vm --tunnel-through-iap
```

### Key Deliverables
- [ ] GCP Project created with billing linked to free trial
- [ ] Terraform code for VPC, subnets, firewall rules, IAM, service accounts
- [ ] Custom VM image built with Packer (Ubuntu 22.04 + NVIDIA drivers + CUDA + Docker + Enroot)
- [ ] Ansible playbook repo with roles: `common`, `gpu-node`, `storage-client`
- [ ] IAP Tunnel SSH access working (no bastion needed!)
- [ ] Architecture diagram documenting VPC layout
- [ ] Required GCP APIs enabled

---

## Phase 2 — Container Platform Setup & GPU Enablement

> **🧑‍🎓 Why this phase?** We need a way to run containers on GPU machines. This phase sets up Google Kubernetes Engine (GKE) with GPU support, so we can say "run this PyTorch container on 2 GPUs" and K8s handles the rest. We also set up Artifact Registry to store our custom images.

> **GKE Advantage:** GKE offers one free Zonal or Autopilot cluster per billing account — no management fee! That's ~$74/month saved compared to EKS ($0.10/hr).

**Goal:** Deploy GKE with NVIDIA GPU support. Set up Artifact Registry for container image storage.

### What to Do
- Deploy GKE cluster (Standard or Autopilot) using Terraform or `gcloud`
- Add a GPU node pool with T4 GPUs (Spot VMs for cost savings)
- Install NVIDIA GPU drivers on GKE nodes (automatic with GKE!)
- Create Artifact Registry repository for HPC images
- Build base container images: CUDA base, PyTorch + NCCL, TensorFlow
- Push images to Artifact Registry
- Validate GPU access: run `nvidia-smi` inside a container on GKE

### How to Do It

```bash
# 1. Create GKE cluster (Standard mode, one free zonal cluster!)
#    --zone = single zone to qualify for free tier
#    --num-nodes 1 = just the default pool (we add GPU pool separately)
gcloud container clusters create hpc-gke-poc \
  --zone us-central1-a \
  --num-nodes 1 \
  --machine-type e2-standard-2 \
  --network hpc-vpc \
  --subnetwork hpc-subnet

# 2. Add GPU node pool with T4 GPUs (Spot VMs = cheapest!)
#    --accelerator type=nvidia-tesla-t4,count=1 = 1 T4 GPU per node
#    --spot = use Spot VMs (~$0.11/hr per GPU, 70% cheaper than on-demand)
#    --num-nodes 0 = start with zero (autoscaler adds nodes when needed)
#    --enable-autoscaling = auto add/remove nodes based on demand
gcloud container node-pools create gpu-t4-pool \
  --cluster hpc-gke-poc \
  --zone us-central1-a \
  --machine-type n1-standard-4 \
  --accelerator type=nvidia-tesla-t4,count=1 \
  --spot \
  --num-nodes 0 \
  --min-nodes 0 \
  --max-nodes 4 \
  --enable-autoscaling

# 3. Install NVIDIA GPU drivers (GKE has a built-in DaemonSet!)
kubectl apply -f https://raw.githubusercontent.com/GoogleCloudPlatform/container-engine-accelerators/master/nvidia-driver-installer/cos/daemonset-preloaded.yaml

# 4. Create Artifact Registry repository
gcloud artifacts repositories create hpc-images \
  --repository-format=docker \
  --location=us-central1 \
  --description="HPC container images"

# 5. Configure Docker to push to Artifact Registry
gcloud auth configure-docker us-central1-docker.pkg.dev

# 6. Build and push a container image
docker build -t us-central1-docker.pkg.dev/hpc-container-poc/hpc-images/pytorch-ddp:latest .
docker push us-central1-docker.pkg.dev/hpc-container-poc/hpc-images/pytorch-ddp:latest

# 7. Test GPU access from inside a container on GKE
kubectl run gpu-test \
  --image=nvidia/cuda:12.2.0-base-ubuntu22.04 \
  --restart=Never \
  --overrides='{
    "spec": {
      "nodeSelector": {"cloud.google.com/gke-accelerator": "nvidia-tesla-t4"},
      "containers": [{
        "name": "gpu-test",
        "image": "nvidia/cuda:12.2.0-base-ubuntu22.04",
        "command": ["nvidia-smi"],
        "resources": {"limits": {"nvidia.com/gpu": 1}}
      }]
    }
  }' \
  -- nvidia-smi
```

#### GKE GPU Support — What Happens Automatically

| Component | What It Does | GKE Behavior |
|-----------|-------------|-------------|
| **GPU Driver** | NVIDIA kernel driver so Linux can see the GPU | Auto-installed via DaemonSet |
| **Device Plugin** | Tells Kubernetes "this node has X GPUs available" | Built into GKE — automatic |
| **Container Toolkit** | Allows containers to access the GPU hardware | Included in the DaemonSet |
| **DCGM Exporter** | Exports GPU metrics for monitoring | Install separately (Phase 8) |

### Key Deliverables
- [ ] GKE cluster running (free zonal cluster)
- [ ] GPU node pool with T4 Spot VMs (0-4 autoscaling)
- [ ] NVIDIA GPU drivers installed via DaemonSet
- [ ] Artifact Registry repository created
- [ ] Base PyTorch container image pushed to Artifact Registry
- [ ] `nvidia-smi` works inside a GKE pod (confirms GPU passthrough)
- [ ] `vectorAdd` CUDA sample runs successfully in a container

---

## Phase 3 — HPC Scheduler Integration (SLURM on GCP)

> **🧑‍🎓 Why this phase?** Kubernetes is great for running containers, but HPC researchers are used to SLURM. This phase creates a SLURM cluster on GCP using **Cloud HPC Toolkit** and adds container support.

> **What is Cloud HPC Toolkit?** Google's open-source tool (similar to AWS ParallelCluster). You write a YAML blueprint describing your cluster, run `ghpc deploy`, and it builds a full SLURM cluster — controller, login node, auto-scaling GPU compute partitions.

> **What is Pyxis/Enroot?** Pyxis is an NVIDIA SLURM plugin that lets users add `--container-image=pytorch:latest` to their `sbatch` command. Enroot is the container runtime Pyxis uses — designed for HPC (no root needed, fast image pulls).

**Goal:** Deploy a SLURM cluster on GCP with GPU nodes and container support (Pyxis/Enroot).

### What to Do
- Install Cloud HPC Toolkit (`ghpc`)
- Create a blueprint YAML for the SLURM cluster
- Deploy the cluster with `ghpc deploy`
- Install Pyxis + Enroot on compute nodes (via custom image or startup script)
- Validate: submit a containerized SLURM job that uses GPUs
- Test multi-node MPI jobs inside containers

### How to Do It

#### Cloud HPC Toolkit Blueprint (What Each Section Does)

```yaml
# hpc-slurm-blueprint.yaml
blueprint_name: hpc-poc-slurm

vars:
  project_id: hpc-container-poc
  deployment_name: hpc-poc
  region: us-central1
  zone: us-central1-a

deployment_groups:
- group: primary
  modules:

  # Network — uses our existing VPC or creates a new one
  - id: network
    source: modules/network/vpc

  # SLURM controller node (the "head node" — runs slurmctld)
  - id: slurm_controller
    source: community/modules/scheduler/schedmd-slurm-gcp-v6-controller
    use: [network]
    settings:
      machine_type: n1-standard-4     # 4 vCPU, 15 GB — no GPU needed
      disk_size_gb: 50

  # Login node — researchers SSH here to submit jobs
  - id: slurm_login
    source: community/modules/scheduler/schedmd-slurm-gcp-v6-login
    use: [slurm_controller, network]
    settings:
      machine_type: n1-standard-2     # 2 vCPU — just for SSH + sbatch

  # GPU compute partition — auto-scales from 0 to 4
  - id: gpu_partition
    source: community/modules/compute/schedmd-slurm-gcp-v6-nodeset
    use: [network]
    settings:
      node_count_dynamic_max: 4       # Scale up to 4 GPU nodes
      machine_type: n1-standard-4     # 4 vCPU per GPU node
      accelerator_type: nvidia-tesla-t4  # T4 GPU — cheapest option
      accelerator_count: 1            # 1 GPU per node
      preemptible: true               # Spot/Preemptible = ~70% savings!
      disk_size_gb: 100
```

#### Deploy the Cluster

```bash
# 1. Install Cloud HPC Toolkit
git clone https://github.com/GoogleCloudPlatform/hpc-toolkit.git
cd hpc-toolkit && make install

# 2. Create the deployment from the blueprint
ghpc create hpc-slurm-blueprint.yaml

# 3. Deploy (creates all GCP resources — takes ~10-15 minutes)
ghpc deploy hpc-poc

# 4. SSH into the login node via IAP
gcloud compute ssh hpc-poc-login-0 --tunnel-through-iap --zone us-central1-a
```

#### Submit a Containerized GPU Job

```bash
# Once SSH'd into the login node:
# This tells SLURM: "Run this job inside a PyTorch container, using 1 GPU"
sbatch --container-image=nvcr.io/nvidia/pytorch:24.01-py3 \
       --gpus=1 \
       --wrap="python -c 'import torch; print(torch.cuda.is_available())'"
# Should print: True

# For multi-node:
sbatch --container-image=nvcr.io/nvidia/pytorch:24.01-py3 \
       --nodes=2 --gpus-per-node=1 \
       --wrap="torchrun --nnodes=2 --nproc_per_node=1 train.py"
```

### Key Deliverables
- [ ] Cloud HPC Toolkit installed
- [ ] SLURM cluster deployed: controller + login node + auto-scaling GPU partition
- [ ] Pyxis/Enroot installed on compute nodes
- [ ] Single-node containerized GPU job working (`sbatch --container-image`)
- [ ] Multi-node MPI container job validated
- [ ] User guide: "How to submit a container job on the cluster"

---

## Phase 4 — Job Templates for Batch & Distributed Workloads

> **🧑‍🎓 Why this phase?** Researchers shouldn't have to write complex SLURM scripts or Kubernetes YAML from scratch every time. We create **reusable templates** — fill in your model name, GPU count, and dataset path, and the template generates a ready-to-submit job.

> **What is Jinja2?** A Python templating engine. You write a file with `{{ placeholders }}` and Jinja2 fills them in with actual values.

**Goal:** Build a library of reusable, parameterized job templates for SLURM (Cloud HPC Toolkit) and Kubernetes (GKE).

### What to Do
- Create template library for common GPU workload patterns:
  - **Single-GPU training** — 1 machine, 1 GPU
  - **Multi-GPU single-node** — 1 machine, multiple GPUs (PyTorch DDP)
  - **Multi-node distributed training** — multiple machines, multiple GPUs each
  - **Hyperparameter sweep** — SLURM array jobs
  - **Inference batch job** — run a trained model on new data
  - **Data preprocessing** — CPU-only job
- Support both SLURM (`sbatch`) and K8s (`kubectl apply`) formats
- Build a simple Python CLI: `python submit_job.py --template ddp --nodes 2 --gpus 4`
- Test every template with a real workload (ResNet on CIFAR-10)

### How to Do It

#### SLURM Multi-Node DDP Template
```bash
#!/bin/bash
#SBATCH --job-name={{ job_name }}              # Name shown in 'squeue'
#SBATCH --nodes={{ num_nodes }}                # How many machines
#SBATCH --ntasks-per-node={{ gpus_per_node }}  # One task per GPU
#SBATCH --gpus-per-task=1                      # Each task gets 1 GPU
#SBATCH --mem={{ mem_per_node }}               # RAM per node (e.g., 64G)
#SBATCH --time={{ time_limit }}                # Max run time (e.g., 04:00:00)
#SBATCH --partition=gpu                        # GPU partition from HPC Toolkit
#SBATCH --container-image={{ container_image }}  # Docker image to run in
#SBATCH --container-mounts={{ data_path }}:/data,{{ output_path }}:/output

# PyTorch distributed environment variables
export MASTER_ADDR=$(scontrol show hostnames "$SLURM_JOB_NODELIST" | head -n1)
export MASTER_PORT=29500
export WORLD_SIZE=$(( SLURM_NNODES * SLURM_NTASKS_PER_NODE ))

# Launch training across all GPUs on all nodes
srun torchrun \
  --nnodes=$SLURM_NNODES \
  --nproc_per_node=$SLURM_NTASKS_PER_NODE \
  --rdzv_id=$SLURM_JOB_ID \
  --rdzv_backend=c10d \
  --rdzv_endpoint=$MASTER_ADDR:$MASTER_PORT \
  {{ train_script }} {{ train_args }}
```

#### Kubernetes PyTorchJob Template (GKE)
```yaml
# Uses Kubeflow Training Operator — knows how to run distributed PyTorch
apiVersion: kubeflow.org/v1
kind: PyTorchJob
metadata:
  name: {{ job_name }}
spec:
  pytorchReplicaSpecs:
    Master:
      replicas: 1
      template:
        spec:
          nodeSelector:
            cloud.google.com/gke-accelerator: nvidia-tesla-t4  # GKE GPU selector
          containers:
          - name: pytorch
            image: {{ container_image }}   # Your Artifact Registry image
            resources:
              limits:
                nvidia.com/gpu: {{ gpus_per_node }}
    Worker:
      replicas: {{ num_workers }}
      template:
        spec:
          nodeSelector:
            cloud.google.com/gke-accelerator: nvidia-tesla-t4
          containers:
          - name: pytorch
            image: {{ container_image }}
            resources:
              limits:
                nvidia.com/gpu: {{ gpus_per_node }}
```

#### Simple CLI to Render Templates
```python
# tools/submit_job.py — Run: python submit_job.py --template ddp --nodes 2 --gpus 4
import click
import jinja2

@click.command()
@click.option("--template", required=True, help="Template name: single-gpu, ddp, array")
@click.option("--nodes", default=1, help="Number of nodes")
@click.option("--gpus", default=1, help="GPUs per node")
@click.option("--image", default="pytorch:latest", help="Container image")
def submit(template, nodes, gpus, image):
    """Render a job template and print/submit it."""
    env = jinja2.Environment(loader=jinja2.FileSystemLoader("templates/"))
    tmpl = env.get_template(f"{template}.sh.j2")
    rendered = tmpl.render(num_nodes=nodes, gpus_per_node=gpus, container_image=image)
    print(rendered)
```

### Key Deliverables
- [ ] Template library in Git: `hpc-job-templates/`
- [ ] Templates for: single-GPU, multi-GPU, multi-node DDP, array job, inference
- [ ] CLI tool: `submit_job.py` (renders templates with Jinja2)
- [ ] Each template tested with a real workload (ResNet/CIFAR-10)
- [ ] README with usage examples per template

---

## Phase 5 — Distributed ML Framework Integration

> **🧑‍🎓 Why this phase?** Training large AI models takes too long on a single GPU. We need to split the work across multiple GPUs and multiple machines. This phase tests the major distributed training frameworks.

**Goal:** Build container images with distributed ML support, validate multi-node GPU training, and benchmark scaling efficiency on GCP.

### What to Do
- Build container images with MPI, NCCL, and framework support:
  - **PyTorch DDP** (native, c10d rendezvous)
  - **Horovod** (MPI + NCCL backend)
  - **Ray** (Ray Train for distributed ML)
  - **TensorFlow** (MirroredStrategy / MultiWorkerMirroredStrategy)
- Run NCCL performance tests
- Test scaling: 1 GPU → 2 GPUs → 4 GPUs → 2 nodes × 1 GPU
- Test elastic training (Ray Train)

### How to Do It

#### NCCL Performance Test
```bash
# Measures cross-node GPU communication speed ("allreduce")
docker run --gpus all --network host nvcr.io/nvidia/pytorch:24.01-py3 \
  all_reduce_perf -b 8 -e 4G -f 2 -g 1
#
# ⚠️ EXPECTED RESULTS FOR n1-standard-4 + T4 (Spot):
# - 1 GPU per node, so cross-node NCCL goes over the network
# - GCP default network bandwidth: ~10-32 Gbps (depends on VM size)
# - Expect ~1.5-3 GB/s for cross-node allreduce
# - This is NORMAL for single-GPU nodes — NOT a problem
# - >10 GB/s needs multi-GPU nodes with NVLink (a2, a3 series)
# - For POC: 1.5-3 GB/s proves the pattern works; upgrade later
```

#### PyTorch DDP Multi-Node Example
```bash
# On Node 0 (master):
torchrun --nnodes=2 --nproc_per_node=1 \
         --rdzv_id=job123 --rdzv_backend=c10d \
         --rdzv_endpoint=node0:29500 train.py

# On Node 1 (worker):
torchrun --nnodes=2 --nproc_per_node=1 \
         --rdzv_id=job123 --rdzv_backend=c10d \
         --rdzv_endpoint=node0:29500 train.py

# SLURM handles all of this automatically with srun
```

#### Ray Cluster on SLURM
```python
import ray
from ray.train.torch import TorchTrainer

ray.init()  # Connects to the Ray cluster

trainer = TorchTrainer(
    train_func,
    scaling_config=ray.train.ScalingConfig(
        num_workers=4,
        use_gpu=True,
        resources_per_worker={"GPU": 1}
    ),
)
result = trainer.fit()
```

### Benchmarks to Run
| Test | What It Measures | Expected Outcome (n1-standard-4 + T4) |
|------|-----------------|--------------------------------------|
| NCCL allreduce (2-4 nodes) | Cross-node GPU communication speed | **~1.5-3 GB/s** (limited by ~10-32 Gbps network — normal for single-GPU nodes) |
| DDP scaling (1 → 2 → 4 nodes) | How much faster training gets with more GPUs | ~1.5-1.7x per 2x nodes (network overhead expected) |
| DDP 1 node vs 2 nodes | Network overhead of cross-machine training | 15-25% overhead (higher than NVLink, expected for PCIe/network) |
| Ray Train vs DDP | Throughput comparison | Should be similar |

> 💡 **Why these numbers look low:** Most published benchmarks use a2/a3 instances with 8× GPUs + NVLink (600 GB/s). Our T4 nodes have 1 GPU each, communicating over standard network — ~100x slower for inter-GPU comms. **Fine for a POC** — we're validating patterns, not chasing peak performance.

### Key Deliverables
- [ ] Container images pushed to Artifact Registry: `pytorch-ddp`, `horovod`, `ray-train`
- [ ] NCCL benchmark results documented
- [ ] Scaling efficiency report (images/sec vs GPU count)
- [ ] Ray cluster on SLURM working example
- [ ] Horovod multi-node working example

---

## Phase 6 — Storage Integration

> **🧑‍🎓 Why this phase?** AI training needs data — lots of it. We need storage that all machines can access simultaneously.

**Goal:** Set up shared storage for datasets, checkpoints, and results using GCP storage services.

### What to Do
- Set up Cloud Storage (GCS) bucket for datasets and checkpoints
- Configure Cloud Storage FUSE (gcsfuse) to mount GCS as a filesystem
- Evaluate Filestore (managed NFS) for high-performance shared storage
- Test I/O performance with training workloads
- Implement checkpoint saving/loading from shared storage

### Storage Options on GCP

| Storage | Type | Performance | Cost | Best For |
|---------|------|------------|------|----------|
| **GCS** | Object store | High throughput, high latency | ~$0.02/GB/month | Datasets, checkpoints, logs |
| **GCS + gcsfuse** | FUSE mount | Medium (cached reads) | Same as GCS | POSIX access to GCS data |
| **Filestore Basic** | Managed NFS | Good (up to 480 MB/s) | ~$0.20/GB/month | Shared home dirs, small datasets |
| **Filestore Enterprise** | Managed NFS | Very good (up to 1.2 GB/s) | ~$0.30/GB/month | Large shared datasets |
| **Parallelstore** | Lustre-like | Excellent (100+ GB/s) | ~$0.40/GB/month | Large-scale HPC I/O |

### Key Deliverables
- [ ] GCS bucket created for datasets and checkpoints
- [ ] gcsfuse working on compute nodes (SLURM + GKE)
- [ ] Filestore instance for shared storage (if needed)
- [ ] I/O benchmark results documented
- [ ] Checkpoint save/load tested with distributed training

---

## Phase 7 — Workflow Orchestration Evaluation & Integration

> **🧑‍🎓 Why this phase?** Real ML pipelines have multiple steps: download data → preprocess → train → evaluate → deploy. We need a tool to chain these steps together reliably.

**Goal:** Evaluate and integrate a workflow orchestration tool for multi-step ML pipelines.

### Options to Evaluate

| Tool | Pros | Cons |
|------|------|------|
| **Argo Workflows** | K8s-native, DAG support, GPU-aware | Requires K8s expertise |
| **Kubeflow Pipelines** | ML-focused, experiment tracking | Heavy, complex setup |
| **Prefect / Airflow** | Python-native, large community | Less K8s/GPU integration |

### Key Deliverables
- [ ] Evaluation document comparing orchestration tools
- [ ] Selected tool deployed on GKE
- [ ] Example multi-step pipeline: data prep → train → evaluate
- [ ] Pipeline handles GPU resource requests correctly

---

## Phase 8 — Monitoring, Benchmarking & Performance Tuning

> **🧑‍🎓 Why this phase?** You can't optimize what you can't measure. This phase adds GPU monitoring, job tracking, and performance benchmarks.

**Goal:** Set up comprehensive monitoring for GPU utilization, job performance, and cluster health.

### What to Do
- Deploy DCGM Exporter for GPU metrics
- Set up Google Managed Prometheus (free with GKE!)
- Configure Grafana dashboards for GPU utilization, memory, temperature
- Set up Cloud Monitoring alerts for budget, GPU errors, node failures
- Run performance benchmarks and document baseline results

### Key Deliverables
- [ ] DCGM Exporter running on all GPU nodes
- [ ] Google Managed Prometheus collecting GPU metrics
- [ ] Grafana dashboards: GPU utilization, memory, job throughput
- [ ] Budget alerts configured in GCP
- [ ] Performance benchmark report (baseline numbers)

---

## Phase 9 — CI/CD, IaC & Automation

> **🧑‍🎓 Why this phase?** Manual infrastructure management doesn't scale. This phase automates everything: container builds, infrastructure updates, and deployments.

**Goal:** Automate container image builds, infrastructure provisioning, and deployment pipelines.

### What to Do
- Set up GitHub Actions (or Cloud Build) for container image CI/CD
- Automate: build → scan (Trivy) → push to Artifact Registry
- Terraform modules for all infrastructure
- GitOps workflow: merge to main → auto-deploy infrastructure changes
- Packer pipeline for custom VM images

### Key Deliverables
- [ ] CI/CD pipeline: auto-build container images on push
- [ ] Security scanning (Trivy) integrated into pipeline
- [ ] Terraform modules for: VPC, GKE, SLURM, storage, monitoring
- [ ] Infrastructure changes deployed via pull request
- [ ] Packer build automated for custom VM images

---

## Phase 10 — Auto-Scaling & Production Readiness

> **🧑‍🎓 Why this phase?** The POC needs to demonstrate that the architecture can scale. This phase validates auto-scaling, fault tolerance, and cost optimization.

**Goal:** Validate auto-scaling, implement fault tolerance, and optimize costs for production readiness.

### What to Do
- Test GKE Cluster Autoscaler with GPU node pools
- Test SLURM auto-scaling (Cloud HPC Toolkit)
- Implement Spot VM preemption handling (checkpoint + restart)
- Cost optimization: right-sizing, scheduling policies, idle shutdown
- Document production readiness checklist

### Key Deliverables
- [ ] GKE autoscaling tested: 0 → N GPU nodes on demand
- [ ] SLURM autoscaling tested: nodes spin up/down with job queue
- [ ] Spot preemption handling: auto-checkpoint and restart
- [ ] Cost optimization report with recommendations
- [ ] Production readiness checklist

---

## Summary Phase Timeline (Suggested)

| Phase | Description | Duration |
|-------|------------|----------|
| 1 | Foundation & Infrastructure | 3-4 days |
| 2 | Container Platform & GPU | 3-4 days |
| 3 | SLURM on GCP | 3-4 days |
| 4 | Job Templates | 2-3 days |
| 5 | Distributed ML | 3-4 days |
| 6 | Storage Integration | 2-3 days |
| 7 | Workflow Orchestration | 3-4 days |
| 8 | Monitoring & Benchmarks | 2-3 days |
| 9 | CI/CD & IaC | 3-4 days |
| 10 | Auto-Scaling & Production | 2-3 days |
| **Total** | | **~26-36 days** |

---

## 💰 Estimated GCP Cost for Full POC

| Resource | Hours | Cost/hr | Total |
|----------|-------|---------|-------|
| T4 Spot VMs (4 nodes max) | ~200 hrs total | ~$0.11/GPU | ~$22 |
| n1-standard-4 (non-GPU, controller) | ~300 hrs | ~$0.15 | ~$45 |
| GKE cluster (free zonal) | - | $0 | $0 |
| Artifact Registry | - | ~$0.10/GB | ~$5 |
| GCS storage (100 GB) | 1 month | ~$0.02/GB | ~$2 |
| Filestore Basic (100 GB) | ~200 hrs | ~$0.20/GB/mo | ~$10 |
| Networking (egress) | - | varies | ~$5 |
| Cloud Build (free tier) | - | $0 | $0 |
| **Subtotal** | | | **~$89** |
| **Buffer (3x for mistakes/reruns)** | | | **~$267** |
| **Free credits** | | | **-$300** |
| **Net cost** | | | **~$0** ✅ |

> 💡 With $300 free credits, the entire POC should be **free** if you stay disciplined with Spot VMs and shut down resources when not in use.

---

## Tech Stack Summary (GCP-Specific)

| Layer | Technology |
|-------|-----------|
| **Cloud** | GCP (us-central1) |
| **Compute** | GCE (n1-standard-4 + T4 Spot) |
| **Container Runtime** | Docker, Enroot, containerd |
| **Container Registry** | Artifact Registry |
| **Orchestration** | GKE (Kubernetes), Cloud HPC Toolkit (SLURM) |
| **GPU Support** | NVIDIA Container Toolkit, DCGM, NCCL |
| **ML Frameworks** | PyTorch DDP, Horovod, Ray Train |
| **Storage** | GCS, gcsfuse, Filestore |
| **Monitoring** | Google Managed Prometheus, Grafana, DCGM Exporter |
| **IaC** | Terraform (Google provider), Ansible, Packer |
| **CI/CD** | GitHub Actions / Cloud Build |
| **Networking** | VPC, gVNIC, IAP Tunnel |

---

## Prerequisites (What You Need Before Starting)

- [ ] GCP account with $300 free trial credits
- [ ] `gcloud` CLI installed and authenticated
- [ ] `kubectl` installed
- [ ] `terraform` installed (v1.5+)
- [ ] `packer` installed
- [ ] `ansible` installed
- [ ] Docker Desktop installed (for local image builds)
- [ ] Git + GitHub account
- [ ] Basic familiarity with Linux command line

---

## Decisions Made ✅

| Decision | Choice | Why |
|----------|--------|-----|
| Cloud provider | GCP | $300 free credits, free GKE tier, cheaper T4 Spot VMs |
| Region | us-central1 | Cheapest GPU pricing on GCP |
| GPU | T4 (Spot) | Cheapest NVIDIA GPU ($0.11/hr), 16GB VRAM, full CUDA support |
| Container registry | Artifact Registry | GCP-native, supports Docker + other formats |
| HPC scheduler | Cloud HPC Toolkit (SLURM) | Open-source, GCP-native, auto-scaling |
| K8s | GKE (Standard, Zonal) | Free management fee for one zonal cluster |
| SSH access | IAP Tunnel | No bastion host needed, free, more secure |
| Storage | GCS + gcsfuse + Filestore | Flexible, cost-effective, POSIX-compatible |
| Monitoring | GMP + Grafana + DCGM | Free with GKE, GPU-specific metrics |
| IaC | Terraform + Ansible | Industry standard, GCP provider support |
| CI/CD | GitHub Actions | Free for public repos, familiar workflow |

## Open Questions

- [ ] Should we use GKE Autopilot instead of Standard mode?
- [ ] Filestore vs Parallelstore for high-performance shared storage?
- [ ] Which workflow orchestrator: Argo Workflows vs Kubeflow Pipelines?
- [ ] Do we need GPUDirect-TCPXO for cross-node GPU communication?
- [ ] Should we evaluate Vertex AI for managed ML training?
