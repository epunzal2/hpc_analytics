#!/bin/bash

# --- Configuration ---
LOG_DIR="." # Log directory (current directory by default)
LOG_FILE="$LOG_DIR/rehearsal_log_$(date '+%Y-%m-%d').txt"
TEST_JOB_SCRIPT="test_job.slurm"
# --- Environment Check Configuration ---
# Adjust these as needed for your environment
CHECK_MODULE="cuda" # Example module to check loading
CHECK_FS="/scratch" # Example filesystem to check access
CHECK_CACHE="/cache/home/username" # Example cache directory

# --- Helper Functions ---
log_message() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" >> "$LOG_FILE"
    echo "$1" # Also print to stdout for immediate feedback
}

anonymize_text() {
    local text="$1"
    local current_user=$(whoami)
    local current_host=$(hostname -s) # Use short hostname
    # Add more sed commands here for other sensitive info if needed
    echo "$text" | sed "s/$current_user/[USER]/g" | sed "s/$current_host/[HOSTNAME]/g"
}

# --- Main Routine ---
log_message "Starting HPC Rehearsal Routine."

# 1. Submit Test Job
log_message "Submitting test job: $TEST_JOB_SCRIPT"
JOB_SUBMISSION_OUTPUT=$(sbatch "$TEST_JOB_SCRIPT")
JOB_ID=$(echo "$JOB_SUBMISSION_OUTPUT" | awk '{print $4}')

if [[ -z "$JOB_ID" || ! "$JOB_ID" =~ ^[0-9]+$ ]]; then
    log_message "ERROR: Failed to submit job or parse Job ID from output: $JOB_SUBMISSION_OUTPUT"
    ANON_ERROR=$(anonymize_text "ERROR: Job submission failed.")
    log_message "$ANON_ERROR"
    exit 1
fi
log_message "Test job submitted with ID: $JOB_ID"

# 2. Wait briefly and Check Job Status/Resources
log_message "Waiting 15 seconds for job completion..."
sleep 15

JOB_STATE_RAW=$(sacct -j "$JOB_ID" --format=State --noheader | head -n 1 | xargs) # Get primary state, trim whitespace
JOB_RESOURCES_RAW=$(sacct -j "$JOB_ID" --format=CPUTimeRaw,MaxRSS --noheader | head -n 1)

JOB_STATUS="UNKNOWN"
CPU_TIME_RAW="N/A"
MEM_USAGE_KB="N/A" # MaxRSS is usually in KB

if [[ -n "$JOB_STATE_RAW" ]]; then
    if [[ "$JOB_STATE_RAW" == "COMPLETED" ]]; then
        JOB_STATUS="SUCCESS"
    else
        JOB_STATUS="FAIL ($JOB_STATE_RAW)"
    fi

    # Parse resources only if state is known
    CPU_TIME_RAW=$(echo "$JOB_RESOURCES_RAW" | awk '{print $1}')
    MEM_USAGE_KB=$(echo "$JOB_RESOURCES_RAW" | awk '{print $2}')
    # Convert MaxRSS (KB) to MB if value exists
    if [[ "$MEM_USAGE_KB" =~ ^[0-9]+K$ ]]; then
        MEM_USAGE_MB=$(awk -v mem_kb="${MEM_USAGE_KB%K}" 'BEGIN { printf "%.2f", mem_kb / 1024 }')
        MEM_USAGE_STR="${MEM_USAGE_MB}MB"
    elif [[ "$MEM_USAGE_KB" =~ ^[0-9]+M$ ]]; then
         MEM_USAGE_STR="$MEM_USAGE_KB" # Already in MB
    elif [[ "$MEM_USAGE_KB" =~ ^[0-9]+G$ ]]; then
         MEM_USAGE_STR="$MEM_USAGE_KB" # Already in GB
    else
        MEM_USAGE_STR="N/A" # Could not parse
    fi

else
    log_message "WARNING: Could not retrieve job state for Job ID $JOB_ID via sacct."
    JOB_STATUS="FAIL (sacct error)"
fi

log_message "Job $JOB_ID Status: $JOB_STATUS, CPU Time Raw: ${CPU_TIME_RAW:-N/A}s, MaxRSS: ${MEM_USAGE_KB:-N/A}"

# 3. Perform Environment Checks
log_message "Performing environment checks..."
ENV_CHECKS_SUMMARY=""

# Check Python (Miniconda or System)
if command -v conda &> /dev/null; then
    # Using Miniconda
    PYTHON_VERSION=$((conda list python | grep python | awk '{print $2}') 2>/dev/null)
    if [[ -z "$PYTHON_VERSION" ]]; then
        PYTHON_STATUS="FAIL"
    else
        PYTHON_STATUS="OK (conda):$PYTHON_VERSION"
    fi
else
    # Using System Python
    PYTHON_VERSION=$(python --version 2>&1)
    if [[ $? -eq 0 ]]; then
        PYTHON_STATUS="OK:$(echo $PYTHON_VERSION | awk '{print $2}')"
    else
        PYTHON_STATUS="FAIL"
    fi
fi
ENV_CHECKS_SUMMARY+="Python($PYTHON_STATUS)"

# Check Module System
module list &> /dev/null
if [[ $? -eq 0 ]]; then
    MODULE_SYS_STATUS="OK"
else
    MODULE_SYS_STATUS="FAIL"
fi
ENV_CHECKS_SUMMARY+=",Modules($MODULE_SYS_STATUS)"


# Check Filesystem Access - /scratch
ls "$CHECK_FS" &> /dev/null
if [[ $? -eq 0 ]]; then
    FS_STATUS="OK"
else
    FS_STATUS="FAIL"
fi
ENV_CHECKS_SUMMARY+=",${CHECK_FS##*/}($FS_STATUS)" # Use last part of path as label

# Check Filesystem Access - /cache/home/[USERID]
CACHE_DIR=$(echo "$CHECK_CACHE" | sed "s/username/$(whoami)/g")
ls "$CACHE_DIR" &> /dev/null
if [[ $? -eq 0 ]]; then
    CACHE_STATUS="OK"
else
    CACHE_STATUS="FAIL"
fi


# Check Specific Module Loads (cuda, intel, mpi, gcc, apptainer)
MODULES_TO_CHECK=("cuda" "intel" "mpi" "gcc" "apptainer")
for MODULE in "${MODULES_TO_CHECK[@]}"; do
    module load "$MODULE" &> /dev/null
    if [[ $? -eq 0 ]]; then
        SPECIFIC_MODULE_STATUS="OK"
        module unload "$MODULE" &> /dev/null # Clean up
    else
        SPECIFIC_MODULE_STATUS="FAIL"
    fi
    ENV_CHECKS_SUMMARY+=",${MODULE^^}($SPECIFIC_MODULE_STATUS)" # Uppercase module name
done

# Check Quota Command
mmlsquota &> /dev/null
if [[ $? -eq 0 ]]; then
    QUOTA_CMD_STATUS="OK"
else
    QUOTA_CMD_STATUS="FAIL"
fi
ENV_CHECKS_SUMMARY+=",QuotaCmd($QUOTA_CMD_STATUS)"

log_message "Environment Check Results: $ENV_CHECKS_SUMMARY"

# 4. Anonymize and Log Summary
SUMMARY_LINE="JobID: $JOB_ID, Status: $JOB_STATUS, CPU: $CPU_TIME_RAW, Mem: $MEM_USAGE_STR, EnvChecks: $ENV_CHECKS_SUMMARY"
ANONYMIZED_SUMMARY=$(anonymize_text "$SUMMARY_LINE")

log_message "Appending anonymized summary to log: $LOG_FILE"
echo "$(date '+%Y-%m-%d %H:%M:%S') - $ANONYMIZED_SUMMARY" >> "$LOG_FILE"

log_message "HPC Rehearsal Routine Finished."

# Provide a simple stdout summary
echo "---"
echo "Rehearsal Summary ($(date '+%Y-%m-%d %H:%M:%S')):"
echo "  Job ID: $JOB_ID"
echo "  Status: $JOB_STATUS"
echo "  CPU Time: $CPU_TIME_RAW"
echo "  Memory MaxRSS: $MEM_USAGE_STR"
echo "  Env Checks: $ENV_CHECKS_SUMMARY"
echo "  Log File: $LOG_FILE"
echo "---"

exit 0
