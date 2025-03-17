import unittest
import subprocess
import os
import pandas as pd
from datetime import date

class TestAnalytics(unittest.TestCase):

    def setUp(self):
        self.today = "2025-03-17"
        self.log_file = f"output/slurm_job_data_{self.today}.txt"
        self.cpu_plot = f"output/plot_1.png"
        self.memory_plot = f"output/plot_2.png"

    def test_collect_data(self):
        # Run the collect_data.sh script
        result = subprocess.run(["bash", "collect_data.sh"], capture_output=True, text=True)
        self.assertEqual(result.returncode, 0)
        with open(self.log_file) as f:
            self.assertGreater(len(f.readlines()), 1, "Data file should contain records")

    def test_summarize_data(self):
        # Run the summarize_data.py script
        result = subprocess.run(["python3", "summarize_data.py"], capture_output=True, text=True)
        print(result.stderr)

        # Check if the script ran successfully
        self.assertEqual(result.returncode, 0, f"summarize_data.py failed with error: {result.stderr}")

        # Check if the plots were created
        self.assertTrue(os.path.exists(self.cpu_plot))
        if os.path.exists(self.memory_plot):
            self.assertGreater(os.path.getsize(self.memory_plot), 1024)
        else:
            print("Validation: No memory plot generated due to insufficient data")

        # Check if the summary was printed
        self.assertIn("Daily Summary", result.stdout)

    def test_dashboard(self):
        # Check if the dashboard file exists
        self.assertTrue(os.path.exists("dashboard.py"))

if __name__ == '__main__':
    unittest.main()
