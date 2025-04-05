# HPC Rehearsal Routine - Process Log

**Objective:** Create scripts and documentation for a daily HPC rehearsal routine as per `TASKS.md`.

**Date:** 2025-04-04

**Steps:**

1.  **Planning:** Defined requirements: daily execution, Slurm test job, resource logging (CPU, Mem), environment checks, anonymization (user, host), timestamped logging, success/fail status, daily log files (`rehearsal_log_YYYY-MM-DD.txt`).
2.  **Environment Checks Defined:** Specified checks for Python version, module system functionality, specific module load (e.g., GCC), and scratch filesystem access.
3.  **File Creation:** Generated the following files:
    *   `rehearsal_routine.sh`: Main orchestration script.
    *   `test_job.slurm`: Simple Slurm test job.
    *   `README.md`: Usage and explanation documentation.
    *   `PROCESS_LOG.md`: This file.
    *   `test_job_gpu.slurm`: Simple Slurm GPU test job.
