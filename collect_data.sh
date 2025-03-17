#!/bin/bash
TODAY=$(date +%Y-%m-%d)
JOBIDS=$(squeue -h -t RUNNING -o "%i" --format="%i" -S "-t" | grep -v ex+)
/usr/bin/sacct --allusers --starttime $TODAY --endtime $(date -d "$TODAY + 1 day" +%Y-%m-%d) --format="JobID,User,Account,Submit,Start,End,CPUTime,ReqMem,MaxRSS,State,AveVMSize" > output/slurm_job_data_$TODAY.txt
