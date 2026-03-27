# SLURM User Guide — HPC Container POC

## Quick Start

### 1. Connect to the Login Node

```bash
gcloud compute ssh hpc-poc-slurm-login-0 --tunnel-through-iap --zone us-central1-a
```

### 2. Check Cluster Status

```bash
sinfo                    # Show partitions and node status
squeue                   # Show running/pending jobs
squeue -u $USER          # Show YOUR jobs only
```

### 3. Submit a GPU Job (with a container)

```bash
# Simplest possible GPU job — runs nvidia-smi inside a PyTorch container
sbatch --container-image=nvcr.io/nvidia/pytorch:24.01-py3 \
       --gpus=1 \
       --wrap="nvidia-smi && python -c 'import torch; print(torch.cuda.is_available())'"
```

### 4. Submit a Job Script

```bash
sbatch examples/single-gpu-job.sh
```

### 5. Monitor Your Job

```bash
squeue -u $USER          # Check job status (PD=pending, R=running)
scancel <job_id>         # Cancel a job
tail -f logs/job_*.out   # Watch the output in real time
```

---

## Key SLURM Commands

| Command | What It Does |
|---------|-------------|
| `sbatch script.sh` | Submit a batch job (runs in background) |
| `srun --gpus=1 nvidia-smi` | Run a command interactively (waits for output) |
| `squeue` | Show all jobs in the queue |
| `squeue -u $USER` | Show your jobs only |
| `scancel <job_id>` | Cancel a job |
| `scancel -u $USER` | Cancel ALL your jobs |
| `sinfo` | Show partition/node status |
| `sacct -j <job_id>` | Show completed job details (time, memory, etc.) |

---

## Container Flags (Pyxis)

These flags work with `sbatch`, `srun`, and `salloc`:

| Flag | Example | What It Does |
|------|---------|-------------|
| `--container-image` | `nvcr.io/nvidia/pytorch:24.01-py3` | Run inside this container image |
| `--container-mounts` | `/data:/data,/models:/models` | Mount host directories into the container |
| `--container-workdir` | `/workspace` | Set working directory inside container |
| `--container-name` | `my-container` | Reuse a previously created container |

---

## Common Job Patterns

### Single GPU Training
```bash
sbatch --container-image=nvcr.io/nvidia/pytorch:24.01-py3 \
       --gpus=1 --mem=12G --time=04:00:00 \
       --wrap="python train.py --epochs 50"
```

### Multi-Node DDP (2 nodes, 1 GPU each)
```bash
sbatch --container-image=nvcr.io/nvidia/pytorch:24.01-py3 \
       --nodes=2 --gpus-per-node=1 --mem=12G --time=08:00:00 \
       multi-node-ddp-job.sh
```

### Hyperparameter Sweep (6 runs in parallel)
```bash
sbatch --container-image=nvcr.io/nvidia/pytorch:24.01-py3 \
       --array=0-5 --gpus=1 --mem=12G --time=01:00:00 \
       hyperparameter-sweep.sh
```

### Interactive Session (for debugging)
```bash
srun --container-image=nvcr.io/nvidia/pytorch:24.01-py3 \
     --gpus=1 --mem=12G --time=01:00:00 --pty bash
# Now you're inside a container with a GPU — run python, debug, etc.
```

---

## What Happens When You Submit a Job

```
You: sbatch --gpus=1 --container-image=pytorch job.sh
         │
         ▼
SLURM controller receives the job
         │
         ▼
No GPU nodes running? Auto-scaler spins one up (~2-3 min)
         │
         ▼
Pyxis/Enroot pulls the container image
         │
         ▼
Job runs inside the container with GPU access
         │
         ▼
Job finishes → output saved to logs/
         │
         ▼
Node idle for ~5 min → auto-scaler shuts it down → $0/hr
```

---

## Cost Awareness

| Component | Cost | When |
|-----------|------|------|
| Controller node | ~$0.15/hr | Always on while cluster exists |
| Login node | ~$0.07/hr | Always on while cluster exists |
| GPU compute (T4 Spot) | ~$0.11/hr per node | Only when jobs are running |
| GPU compute idle | $0 | Auto-scales to 0 |

**To stop all charges:** Destroy the cluster when not in use:
```
# From GitHub Actions → SLURM Deploy/Destroy → "destroy"
# Or locally: ghpc destroy hpc-poc-slurm --auto-approve
```
