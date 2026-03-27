#!/bin/bash
# ===========================================================================
# Example: Multi-Node Distributed Training (PyTorch DDP)
# ===========================================================================
#
# WHAT: Trains a model across 2 machines with 1 GPU each (2 GPUs total)
# HOW:  sbatch multi-node-ddp-job.sh
#
# PyTorch DDP (DistributedDataParallel) splits the training batch across
# GPUs. Each GPU trains on a portion of the data, then they sync gradients
# using NCCL (the GPU communication library).
#
# SLURM + Pyxis handles all the orchestration:
#   - Starts the container on both nodes
#   - Sets up networking between them
#   - Passes the right environment variables

#SBATCH --job-name=ddp-2node             # Name shown in 'squeue'
#SBATCH --partition=gpu                   # Use GPU partition
#SBATCH --nodes=2                         # 2 machines
#SBATCH --ntasks-per-node=1               # 1 task (process) per machine
#SBATCH --gpus-per-task=1                 # 1 GPU per task
#SBATCH --mem=12G                         # 12 GB RAM per node
#SBATCH --time=02:00:00                   # Max 2 hours
#SBATCH --output=logs/%x_%j.out          # Log file
#SBATCH --container-image=nvcr.io/nvidia/pytorch:24.01-py3
#SBATCH --container-mounts=/data:/data    # Mount shared storage

# --- Environment Setup ---
# SLURM sets these automatically, but we need a few more for PyTorch DDP
export MASTER_ADDR=$(scontrol show hostnames "$SLURM_JOB_NODELIST" | head -n1)
export MASTER_PORT=29500
export WORLD_SIZE=$((SLURM_NNODES * SLURM_NTASKS_PER_NODE))

echo "=== DDP Job Started ==="
echo "Nodes: $SLURM_NNODES"
echo "Master: $MASTER_ADDR:$MASTER_PORT"
echo "World size: $WORLD_SIZE"

# --- Launch Training ---
# torchrun handles per-node process spawning
# --rdzv (rendezvous) = how workers find each other
srun torchrun \
  --nnodes=$SLURM_NNODES \
  --nproc_per_node=$SLURM_NTASKS_PER_NODE \
  --rdzv_id=$SLURM_JOB_ID \
  --rdzv_backend=c10d \
  --rdzv_endpoint=$MASTER_ADDR:$MASTER_PORT \
  train.py \
    --epochs 10 \
    --batch-size 64 \
    --data-dir /data/dataset

echo "=== DDP Job Finished ==="
