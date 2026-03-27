#!/bin/bash
# ===========================================================================
# Example: Hyperparameter Sweep (SLURM Array Job)
# ===========================================================================
#
# WHAT: Runs the same training script 6 times with different learning rates
# HOW:  sbatch hyperparameter-sweep.sh
#
# SLURM array jobs are perfect for hyperparameter sweeps:
#   - Each array task gets a unique SLURM_ARRAY_TASK_ID (0, 1, 2, ...)
#   - All tasks run in parallel (if enough GPUs available)
#   - Each gets its own GPU and log file
#
# This example tests 6 learning rates in parallel on 6 GPUs.

#SBATCH --job-name=hp-sweep               # Name shown in 'squeue'
#SBATCH --partition=gpu                    # Use GPU partition
#SBATCH --array=0-5                        # 6 tasks (IDs: 0,1,2,3,4,5)
#SBATCH --gpus=1                           # 1 GPU per task
#SBATCH --mem=12G                          # 12 GB RAM per task
#SBATCH --time=01:00:00                    # Max 1 hour per task
#SBATCH --output=logs/%x_%A_%a.out        # Log: hp-sweep_12345_0.out
#SBATCH --container-image=nvcr.io/nvidia/pytorch:24.01-py3

# --- Define hyperparameters ---
LEARNING_RATES=(0.001 0.0005 0.0001 0.00005 0.00001 0.000005)
LR=${LEARNING_RATES[$SLURM_ARRAY_TASK_ID]}

echo "=== Hyperparameter Sweep ==="
echo "Task ID: $SLURM_ARRAY_TASK_ID"
echo "Learning rate: $LR"
echo "GPU: $(nvidia-smi --query-gpu=name --format=csv,noheader)"

python train.py \
  --learning-rate $LR \
  --epochs 20 \
  --output-dir /results/sweep_${SLURM_ARRAY_JOB_ID}/lr_${LR}

echo "=== Task $SLURM_ARRAY_TASK_ID finished ==="
