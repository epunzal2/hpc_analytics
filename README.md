# HPC Usage Analytics System

## Overview
A system for collecting and analyzing SLURM job data from HPC clusters. Provides:
- Daily resource usage reports (CPU/GPU hours, memory)
- Visualization of usage patterns
- Streamlit dashboard for interactive exploration

## Requirements
- Python 3.8+
- SLURM workload manager
- pandas, matplotlib, seaborn, streamlit

## Installation
```bash
git clone [repo-url]
cd hpc_analytics
pip install -r requirements.txt
```

## Usage
```bash
# Generate daily report
./generate_report.sh

# Start dashboard
streamlit run dashboard.py
```

## File Structure
```
hpc_analytics/
├── collect_data.sh      # Data collection script
├── summarize_data.py    # Analysis and visualization
├── dashboard.py         # Interactive web interface
└── output/              # Generated reports and plots
