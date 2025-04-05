import pandas as pd
import os
from anonymize import Anonymizer

class GPUTracker:
    def __init__(self, data_path):
        self.data_path = data_path
        self.df = pd.read_csv(self.data_path)
        self.anon = Anonymizer(os.getenv('ANON_SECRET'))
        
    def process_data(self):
        self.df['user_hash'] = self.df.User.apply(self.anon.hash_field)
        self.df['node_hash'] = self.df.NodeList.apply(self.anon.hash_field)

        # Extract GPU count and calculate GPU hours
        self.df['gpu_count'] = self.df['AllocTRES'].str.extract(r'gres/gpu=(\d+)').astype(float).fillna(0).astype(int)
        # Handle "Unknown" elapsed time and "node=" strings
        self.df['Elapsed'] = self.df['Elapsed'].replace(['Unknown', r',node=\d+'], ['00:00:00', ''], regex=True)
        self.df['gpu_hours'] = self.df['gpu_count'] * pd.to_timedelta(self.df['Elapsed'], errors='coerce').dt.total_seconds() / 3600
        self.df['gpu_hours'] = self.df['gpu_hours'].fillna(0)

    def get_busy_nodes(self):
        print("Identifying busy nodes...")
        # Group by node and sum GPU hours
        node_gpu_hours = self.df.groupby('node_hash')['gpu_hours'].sum()

        # Identify nodes with total GPU hours above a threshold (e.g., 1 hour)
        busy_nodes = node_gpu_hours[node_gpu_hours > 1].index.tolist()

        print(f"Busy nodes: {busy_nodes}")
        return busy_nodes
