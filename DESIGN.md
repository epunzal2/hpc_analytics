# System Design

## Architecture
1. Data Collection: SLURM sacct data -> CSV
2. Processing: Pandas-based analysis
3. Visualization: Matplotlib/Seaborn plots
4. Dashboard: Streamlit web interface

## Key Components
- Automated CSV parsing with error handling
- Memory unit conversion (KB/MB/GB)
- User anonymization through ID mapping
- Batch processing for daily reports

## Data Flow
```
SLURM API -> collect_data.sh -> summarize_data.py -> dashboard.py
```

## Architecture Diagram

```mermaid
graph TD
    A[SLURM API] --> B[collect_data.sh]
    B --> C[Raw CSV Data]
    C --> D[summarize_data.py]
    D --> E[Processed Metrics]
    E --> F[generate_plots]
    F --> G[Visualization PNGs]
    E --> H[dashboard.py]
    H --> I[Streamlit Interface]
