#!/bin/bash
#SBATCH --job-name=daily_rehearsal
#SBATCH --output=rehearsal_job_%j.log # Log job output to a file
#SBATCH --error=rehearsal_job_%j.err  # Log job errors to a file
#SBATCH --time=00:01:00             # Max runtime 1 minute
#SBATCH --mem=100M                  # Max memory 100 MB
#SBATCH --nodes=1                   # Run on a single node
#SBATCH --ntasks=1                  # Run a single task

echo "HPC Rehearsal Job Started: $(date)"
echo "Running on host: $(hostname)"
echo "User: $(whoami)"
sleep 10 # Simulate some minimal work
echo "HPC Rehearsal Job Finished: $(date)"
exit 0 # Explicitly exit with success code
