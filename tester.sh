#!/bin/bash
# Diffing Baselines Script
# This script captures baseline snapshots of system service info and configuration,
# then diffs the new output against the previous baseline.
# Baseline files are stored in /root/DIFF as <name>_current.txt and <name>_previous.txt.
# Differences (if any) are stored in /root/DIFF/CHANGES/<name>_diff.txt.

# Define directories
BASE_DIR="/root/DIFF"
CHANGES_DIR="${BASE_DIR}/CHANGES"
mkdir -p "${BASE_DIR}" "${CHANGES_DIR}"

# Declare an associative array of commands.
# Keys are short names; values are the commands to run.
declare -A commands
commands[aureport]="aureport -i"
commands[services]="sudo systemctl list-units --type=service --state=active"
commands[port]="sudo lsof -i -n | grep 'LISTEN'"
commands[connection]="sudo ss -t state established"
commands[alias]="sudo cat /root/.bashrc"
commands[executables]="sudo find / -type f -executable 2>/dev/null"
commands[cron]='for user in $(cut -f1 -d: /etc/passwd); do crontab -u $user -l 2>/dev/null; done'
commands[users]="sudo cat /etc/shadow"
commands[rootkit]="sudo chkrootkit"

# Loop over each command, capturing and diffing the outputs.
for key in "${!commands[@]}"; do
    echo "Processing ${key} baseline..."
    current_file="${BASE_DIR}/${key}_current.txt"
    previous_file="${BASE_DIR}/${key}_previous.txt"
    diff_file="${CHANGES_DIR}/${key}_diff.txt"

    # If a current baseline exists, move it to previous.
    if [ -f "$current_file" ]; then
        mv "$current_file" "$previous_file"
    fi

    # Run the command and save its output as the new current baseline.
    # Using eval so that any shell constructs (like the for loop in cron) work properly.
    eval ${commands[$key]} > "$current_file"

    # If a previous baseline exists, perform a unified diff.
    if [ -f "$previous_file" ]; then
        diff -u "$previous_file" "$current_file" > "$diff_file"
        if [ -s "$diff_file" ]; then
            echo "Differences found for ${key} (see ${diff_file})."
        else
            echo "No differences found for ${key}."
            rm -f "$diff_file"
        fi
    else
        echo "No previous baseline for ${key}. Baseline saved as current."
    fi
done

echo "Diffing complete. Baseline files are in ${BASE_DIR} and diffs (if any) in ${CHANGES_DIR}."
