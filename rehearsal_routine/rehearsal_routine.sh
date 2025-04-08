#!/bin/bash

###############################################################################
# HPC Daily Rehearsal Routine - Refactored Version
# This script submits CPU and GPU test jobs, performs environment checks,
# logs anonymized results, and provides a summary.
###############################################################################

# =========================
# Configuration Parameters
# =========================
LOG_DIR="."
LOG_FILE="$LOG_DIR/rehearsal_log_$(date '+%Y-%m-%d').txt"
CPU_JOB_SCRIPT="test_job.slurm"
GPU_JOB_SCRIPT="test_job_gpu.slurm"

# These can be moved to a config file in the future
CHECK_FS="/scratch"
CHECK_CACHE="/cache/home/$USER"
MODULES_TO_CHECK=("cuda" "intel" "mpi" "gcc" "apptainer")

# =========================
# Logging Function
# =========================
log_message() {
    local level="$1"
    local message="$2"
    local timestamp
    timestamp="$(date '+%Y-%m-%d %H:%M:%S')"
    echo "$timestamp - $level - $message" >> "$LOG_FILE"
    echo "$message"
}

# =========================
# Anonymization Function
# =========================
anonymize_text() {
    local text="$1"
    local user
    user="$(whoami)"
    local host
    host="$(hostname -s)"
    echo "$text" | sed "s/$user/[USER]/g" | sed "s/$host/[HOSTNAME]/g"
}

# =========================
# Submit a Slurm Job
# =========================
submit_job() {
    local job_script="$1"
    local job_type="$2"
    log_message "INFO" "Submitting $job_type job: $job_script"
    local output
    output=$(sbatch "$job_script" 2>&1)
    local job_id
    job_id=$(echo "$output" | awk '{print $4}')
    if [[ -z "$job_id" || ! "$job_id" =~ ^[0-9]+$ ]]; then
        log_message "ERROR" "Failed to submit $job_type job: $output"
        return 1
    fi
    log_message "INFO" "$job_type job submitted with ID: $job_id"
    echo "$job_id"
}

# =========================
# Check Slurm Job Status and Resources
# =========================
check_job_status() {
    local job_id="$1"
    sleep 15
    local state
    state=$(sacct -j "$job_id" --format=State --noheader | head -n1 | xargs)
    local resources
    resources=$(sacct -j "$job_id" --format=CPUTimeRaw,MaxRSS --noheader | head -n1)
    local cpu_time mem_raw mem_str
    cpu_time=$(echo "$resources" | awk '{print $1}')
    mem_raw=$(echo "$resources" | awk '{print $2}')

    # Convert memory units
    if [[ "$mem_raw" =~ ^[0-9]+K$ ]]; then
        mem_str="$(awk -v kb="${mem_raw%K}" 'BEGIN { printf "%.2fMB", kb/1024 }')"
    elif [[ "$mem_raw" =~ ^[0-9]+M$ || "$mem_raw" =~ ^[0-9]+G$ ]]; then
        mem_str="$mem_raw"
    else
        mem_str="N/A"
    fi

    # Determine status
    local status
    if [[ "$state" == "COMPLETED" ]]; then
        status="SUCCESS"
    elif [[ -n "$state" ]]; then
        status="FAIL ($state)"
    else
        status="FAIL (unknown)"
    fi

    echo "$status|$cpu_time|$mem_str"
}

# =========================
# Perform Environment Checks
# =========================
perform_env_checks() {
    local summary=""

    # Python version
    if command -v conda &>/dev/null; then
        local py_ver
        py_ver=$(conda list python | grep python | awk '{print $2}' 2>/dev/null)
        if [[ -n "$py_ver" ]]; then
            summary+="Python(OK (conda):$py_ver)"
        else
            summary+="Python(FAIL)"
        fi
    else
        local py_ver
        py_ver=$(python --version 2>&1 | awk '{print $2}')
        if [[ $? -eq 0 && -n "$py_ver" ]]; then
            summary+="Python(OK:$py_ver)"
        else
            summary+="Python(FAIL)"
        fi
    fi

    # Module system
    module list &>/dev/null
    if [[ $? -eq 0 ]]; then
        summary+=",Modules(OK)"
    else
        summary+=",Modules(FAIL)"
    fi

    # Filesystem check
    ls "$CHECK_FS" &>/dev/null
    if [[ $? -eq 0 ]]; then
        summary+=",${CHECK_FS##*/}(OK)"
    else
        summary+=",${CHECK_FS##*/}(FAIL)"
    fi

    # Cache directory check
    local cache_dir="${CHECK_CACHE/username/$(whoami)}"
    ls "$cache_dir" &>/dev/null
    if [[ $? -eq 0 ]]; then
        summary+=",Cache(OK)"
    else
        summary+=",Cache(FAIL)"
    fi

    # Specific modules
    for mod in "${MODULES_TO_CHECK[@]}"; do
        module load "$mod" &>/dev/null
        if [[ $? -eq 0 ]]; then
            summary+=",${mod^^}(OK)"
            module unload "$mod" &>/dev/null
        else
            summary+=",${mod^^}(FAIL)"
        fi
    done

    # Quota command
    mmlsquota &>/dev/null
    if [[ $? -eq 0 ]]; then
        summary+=",QuotaCmd(OK)"
    else
        summary+=",QuotaCmd(FAIL)"
    fi

    echo "$summary"
}

# =========================
# Main Routine
# =========================
log_message "INFO" "Starting HPC Rehearsal Routine"

# Submit CPU test job
cpu_job_id=$(submit_job "$CPU_JOB_SCRIPT" "CPU")
if [[ -z "$cpu_job_id" ]]; then
    log_message "ERROR" "CPU job submission failed. Exiting."
    exit 1
fi

cpu_result=$(check_job_status "$cpu_job_id")
cpu_status=$(echo "$cpu_result" | cut -d'|' -f1)
cpu_time=$(echo "$cpu_result" | cut -d'|' -f2)
cpu_mem=$(echo "$cpu_result" | cut -d'|' -f3)

# Submit GPU test job
gpu_job_id=$(submit_job "$GPU_JOB_SCRIPT" "GPU")
if [[ -z "$gpu_job_id" ]]; then
    log_message "ERROR" "GPU job submission failed."
    gpu_arch="N/A"
else
    sleep 15
    gpu_log="rehearsal_gpu_job_${gpu_job_id}.log"
    if [[ -f "$gpu_log" ]]; then
        gpu_arch_raw=$(grep "GPU Architecture:" "$gpu_log" | awk -F': ' '{print $2}')
        gpu_arch=$(anonymize_text "$gpu_arch_raw")
    else
        log_message "WARNING" "GPU log file not found: $gpu_log"
        gpu_arch="N/A"
    fi
fi

# Perform environment checks
env_summary=$(perform_env_checks)

# Compose summary line
summary="JobID: $cpu_job_id, Status: $cpu_status, CPU: $cpu_time, Mem: $cpu_mem, GPU: $gpu_arch, EnvChecks: $env_summary"
anon_summary=$(anonymize_text "$summary")

log_message "INFO" "Appending anonymized summary to log"
echo "$(date '+%Y-%m-%d %H:%M:%S') - $anon_summary" >> "$LOG_FILE"

log_message "INFO" "HPC Rehearsal Routine Finished"

# Print final summary
echo "-----------------------------"
echo "Rehearsal Summary ($(date '+%Y-%m-%d %H:%M:%S')):"
echo "  CPU Job ID: $cpu_job_id"
echo "  Status: $cpu_status"
echo "  CPU Time: $cpu_time"
echo "  Memory MaxRSS: $cpu_mem"
echo "  GPU Architecture: $gpu_arch"
echo "  Env Checks: $env_summary"
echo "  Log File: $LOG_FILE"
echo "-----------------------------"

exit 0
