#!/bin/bash
#SBATCH --nodes=1
#SBATCH --time=04:00:00
#SBATCH --job-name=analytics-dashboard

# Activate the conda environment
conda activate base

# Run the Streamlit dashboard
streamlit run dashboard.py --server.port 8501
