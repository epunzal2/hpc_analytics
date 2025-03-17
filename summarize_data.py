#!/usr/bin/env python3

import pandas as pd
import os
from datetime import date
import matplotlib.pyplot as plt
import seaborn as sns
import logging

logging.basicConfig(level=logging.INFO, format='%(asctime)s - %(levelname)s - %(message)s')

def summarize_data(log_file):
    try:
        df = pd.read_csv(log_file, sep='\s+', skiprows=[1])
    except FileNotFoundError:
        logging.error(f"Error: {log_file} not found.")
        return None

    # Data Cleaning and Conversion
    df = df.dropna(axis=1, how='all')
    for col in ['CPUTime', 'ReqMem', 'MaxRSS']:
        if col in df.columns:
            df[col] = df[col].astype(str)  # Convert to string to handle mixed types
    
    # Convert relevant columns to numeric, handling errors
    if 'CPUTime' in df.columns:
        def parse_cputime(tstr):
            try:
                days = 0
                if '-' in tstr:
                    days_str, time_str = tstr.split('-')
                    days = float(days_str)
                    tstr = time_str
                hours, mins, secs = map(float, tstr.split(':'))
                return pd.Timedelta(days=days, hours=hours, minutes=mins, seconds=secs)
            except:
                return pd.Timedelta(0)
        df['CPUTime'] = df['CPUTime'].apply(parse_cputime)
    
    if 'ReqMem' in df.columns:
        df['ReqMem'] = df['ReqMem'].str.extract(r'(\d+)[MG]').astype(float, errors='ignore').fillna(0)
    
    if 'MaxRSS' in df.columns:
        def convert_mem(val):
            if pd.isna(val) or val == '':
                return 0.0
            val = str(val).upper()
            try:
                if 'K' in val: return float(val.replace('K','',1))/1024/1024  # KB to GB
                if 'M' in val: return float(val.replace('M','',1))/1024       # MB to GB
                if 'G' in val: return float(val.replace('G','',1))            # GB
                cleaned_val = val.replace('TIEOUT', '0')
                return float(cleaned_val)/1024/1024  # Assume bytes if no unit
            except ValueError:
                return 0.0
        df['MaxRSS'] = df['MaxRSS'].apply(convert_mem)
    
    print(df.head())

    # Calculate total CPU hours
    total_cpu_hours = df['CPUTime'].dt.total_seconds().sum() / 3600 if 'CPUTime' in df.columns else 0

    # Calculate average requested memory
    avg_req_mem = df['ReqMem'].mean() if 'ReqMem' in df.columns else 0

    # Calculate average max RSS memory usage
    avg_max_rss = df['MaxRSS'].mean() if 'MaxRSS' in df.columns else 0
    
    # GPU Processing
    gpu_hours = 0
    if 'AllocTRES' in df.columns:
        df['gpu_count'] = df['AllocTRES'].str.extract(r'gpu=(\d+)(?:\D|$)').astype(float)
        df['gpu_count'] = df['gpu_count'].fillna(0)
        if 'CPUTime' in df.columns:
            gpu_hours = (df['gpu_count'] * df['CPUTime'].dt.total_seconds() / 3600).sum()

    summary = {
        'Total CPU Hours': total_cpu_hours,
        'Total GPU Hours': gpu_hours,
        'Average Requested Memory (GB)': avg_req_mem / 1024 if avg_req_mem else 0,
        'Average Max RSS Memory Usage (GB)': avg_max_rss / 1024 if avg_max_rss else 0
    }

    return df, summary

def generate_plots(df, today):
    sns.set_theme(style="darkgrid")
    output_dir = "output"
    os.makedirs(output_dir, exist_ok=True)
    user_id_map = {}
    plot_counter = 1

    # Create user mapping
    user_ids = {user: i for i, user in enumerate(df['User'].unique())}
    df['UserID'] = df['User'].map(user_ids)
    user_mapping = pd.DataFrame(list(user_ids.items()), columns=['Username', 'UserID'])
    user_mapping.to_csv(os.path.join(output_dir, 'user_mapping.csv'), index=False)

    # CPU/GPU Hours by User
    if 'User' in df.columns and 'CPUTime' in df.columns:
        # Convert CPUTime to numeric (total seconds)
        df['CPUTime_seconds'] = df['CPUTime'].dt.total_seconds()
        cpu_gpu_hours = df.groupby('UserID')['CPUTime_seconds'].sum() / 3600
        if not cpu_gpu_hours.empty:
            plt.figure(figsize=(18, 12))
            ax = cpu_gpu_hours.sort_values().plot(kind='barh', color='skyblue')
            plt.xlabel('Total CPU Hours', fontsize=14)
            plt.ylabel('User ID', fontsize=14)
            plt.title('Total CPU Hours by User', fontsize=16)
            
            # Improve y-axis labels
            visible_ticks = range(0, len(user_ids), 10)  # Show every 10 users
            ax.set_yticks(visible_ticks)
            ax.set_yticklabels([user_ids.get(i, '') for i in visible_ticks], fontsize=12)
            
            plt.xticks(fontsize=12)
            plt.tight_layout()
            plot_filename = f'{output_dir}/plot_{plot_counter}.png'
            plt.savefig(plot_filename)
            plt.close()
            user_id_map = {user_id: user for user, user_id in user_ids.items()}
            logging.info(f"CPU Hours by User plot saved to {plot_filename}")
            plot_counter += 1
        else:
            logging.warning("No CPU/GPU usage data to plot.")

    # Memory Usage Trends
    if 'UserID' in df.columns and 'MaxRSS' in df.columns:
        df['MaxRSS'] = pd.to_numeric(df['MaxRSS'].replace(r'[^0-9.]', '', regex=True), errors='coerce').fillna(0)
        if (df['MaxRSS'] > 0).sum() > 10 and df['UserID'].nunique() > 1 and df['CPUTime'].apply(lambda x: isinstance(x, pd.Timedelta)).any():
            plt.figure(figsize=(14, 8))  # Increase figure size
            sns.scatterplot(data=df, x='UserID', y='MaxRSS')
            plt.xlabel('User ID', fontsize=14)
            plt.ylabel('Max RSS (GB)', fontsize=14)
            plt.title('Memory Usage Trends', fontsize=16)
            plt.xticks(rotation=45, fontsize=12)  # Rotate and increase font size
            plt.tight_layout()
            plot_filename = f'{output_dir}/plot_{plot_counter}.png'
            plt.savefig(plot_filename)
            plt.close()
            user_id_map = {user_id: user for user, user_id in user_ids.items()}
            logging.info(f"Memory Usage Trends plot saved to {plot_filename}")
            plot_counter += 1
        else:
            logging.warning("No MaxRSS data to plot.")
    
    return user_id_map

if __name__ == "__main__":
    today = date.today().strftime("%Y-%m-%d")
    log_file = f"output/slurm_job_data_{today}.txt"

    if not os.path.exists(log_file):
        logging.error(f"Error: {log_file} not found. Please run collect_data.sh first.")
    else:
        df, summary = summarize_data(log_file)
        if summary:
            print(f"Daily Summary for {today}:")
            for metric, value in summary.items():
                print(f"  {metric}: {value:.2f}")
            user_id_map = generate_plots(df, today)
            print("\nUser ID Map:")
            for plot_num, user_id in user_id_map.items():
                print(f"  Plot {plot_num}: {user_id}")
