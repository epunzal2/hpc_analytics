import streamlit as st
import pandas as pd
import os
from datetime import date

def main():
    st.title("HPC Usage Analytics Dashboard")

    today = date.today().strftime("%Y-%m-%d")
    log_file = f"output/slurm_job_data_{today}.txt"
    
    if not os.path.exists(log_file):
        st.error(f"Error: {log_file} not found. Please run collect_data.sh and summarize_data.py first.")
        return

    try:
        df = pd.read_csv(log_file, sep='|', skiprows=[1])
        st.dataframe(df)
    except Exception as e:
        st.error(f"Error reading or processing {log_file}: {e}")
        return
    
    st.write("## Plots")
    
    cpu_plot = "output/plot_1.png"
    memory_plot = "output/plot_2.png"

    if os.path.exists(cpu_plot):
        st.image(cpu_plot, caption="CPU Hours by User", use_column_width=True)
    else:
        st.warning("CPU Hours plot not generated.")

    if os.path.exists(memory_plot):
        st.image(memory_plot, caption="Memory Usage Trends", use_column_width=True)
    else:
        st.warning("Memory Usage Trends plot not generated.")

    st.write(f"Data from: {today}")

if __name__ == "__main__":
    main()
