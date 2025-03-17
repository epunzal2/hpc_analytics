#!/bin/bash

# Collect data
./collect_data.sh

# Summarize data
echo "Report generated on: $(date)" > daily_report.txt
./summarize_data.py >> daily_report.txt
