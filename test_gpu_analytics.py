import unittest
import pandas as pd
import os
from gpu_analytics import GPUTracker
from anonymize import Anonymizer

class TestGPUTracker(unittest.TestCase):
    
    def setUp(self):
        # Create a dummy gpu_allocations.csv for testing
        self.test_data = """JobID,User,NodeList,AllocTRES,Elapsed,Start,End
42062176|user1|node1|billing=1,cpu=1,gres/gpu=1,mem=8.01G,node=1|72:27:37|2025-03-17T20:34:25|2025-03-17T21:02:02
42062177|user2|node2|billing=1,cpu=1,gres/gpu=2,mem=8.01G,node=1|00:27:37|2025-03-17T20:34:25|2025-03-17T21:02:02
42062178|user1|node1|billing=1,cpu=1,gres/gpu=1,mem=8.01G,node=1|00:27:37|2025-03-17T21:02:02|2025-03-17T21:29:39
"""
        self.test_file = "test_gpu_allocations.csv"
        with open(self.test_file, "w") as f:
            f.write(self.test_data)
        
        # Set ANON_SECRET environment variable
        os.environ['ANON_SECRET'] = "test_secret_key"
        
        self.tracker = GPUTracker(self.test_file)
        self.tracker.process_data()

    def tearDown(self):
        # Remove the test file and environment variable
        os.remove(self.test_file)
        del os.environ['ANON_SECRET']

    def test_process_data(self):
        self.assertIn('user_hash', self.tracker.df.columns)
        self.assertIn('node_hash', self.tracker.df.columns)
        self.assertIn('gpu_count', self.tracker.df.columns)
        self.assertIn('gpu_hours', self.tracker.df.columns)
        self.assertEqual(len(self.tracker.df), 3)

    def test_get_busy_nodes(self):
        busy_nodes = self.tracker.get_busy_nodes()
        self.assertEqual(len(busy_nodes), 1)
        self.assertIn(self.tracker.anon.hash_field('node1'), busy_nodes)

if __name__ == '__main__':
    unittest.main()
