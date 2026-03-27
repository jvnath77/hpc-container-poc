#!/bin/bash
# ===========================================================================
# Example: Single GPU Training Job
# ===========================================================================
#
# WHAT: Runs a PyTorch training script on 1 GPU inside a container
# HOW:  sbatch single-gpu-job.sh
#
# The --container-image flag tells SLURM to run this inside a container
# (using Pyxis/Enroot). No Docker needed, no root needed.

#SBATCH --job-name=single-gpu-train     # Name shown in 'squeue'
#SBATCH --partition=gpu                  # Use the GPU partition
#SBATCH --nodes=1                        # 1 machine
#SBATCH --gpus=1                         # 1 GPU
#SBATCH --mem=12G                        # 12 GB RAM
#SBATCH --time=01:00:00                  # Max 1 hour
#SBATCH --output=logs/%x_%j.out         # Log file: logs/single-gpu-train_12345.out
#SBATCH --container-image=nvcr.io/nvidia/pytorch:24.01-py3

# This runs INSIDE the container
echo "Job started on $(hostname) at $(date)"
echo "GPU available:"
nvidia-smi

python -c "
import torch
print(f'PyTorch version: {torch.__version__}')
print(f'CUDA available: {torch.cuda.is_available()}')
print(f'GPU: {torch.cuda.get_device_name(0)}')

# Simple test: create a tensor on GPU
x = torch.randn(1000, 1000, device='cuda')
y = torch.mm(x, x)
print(f'Matrix multiply on GPU successful! Result shape: {y.shape}')
"

echo "Job finished at $(date)"
