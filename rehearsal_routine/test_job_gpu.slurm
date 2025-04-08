#!/bin/bash
#SBATCH --job-name=daily_rehearsal_gpu
#SBATCH --output=rehearsal_gpu_job_%j.log
#SBATCH --error=rehearsal_gpu_job_%j.err
#SBATCH --time=00:01:00
#SBATCH --mem=100M
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --partition=gpu
#SBATCH --gres=gpu:1 # Request 1 GPU

echo "GPU Rehearsal Job Started: $(date)"
echo "Running on host: $(hostname)"
echo "User: $(whoami)"

# Get GPU Architecture
GPU_ARCHITECTURE=$(nvidia-smi --query-gpu=gpu_name --format=csv,noheader)
echo "GPU Architecture: $GPU_ARCHITECTURE"

echo "GPU Rehearsal Job Finished: $(date)"
exit 0
