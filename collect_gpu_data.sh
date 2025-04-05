#!/bin/bash

# Calculate the start date 1 week ago (Linux compatible)
START_DATE=$(date -d "1 week ago" +%Y-%m-%d)

# Use AllocTRES instead of AllocGRES
/usr/bin/sacct -P -X --format=JobID,User,NodeList,AllocTRES,Elapsed,Start,End \
      --starttime=$START_DATE \
      --units=G \
      --allusers | awk -F'|' '{
          if ($4 ~ /gres\/gpu/) {
              gsub(/,node=[^,]*/, "", $4);
              print $0
          }
      }' > output/gpu_allocations.csv

echo "GPU allocation data for all users (1 week) collected and saved to output/gpu_allocations.csv"
