#!/usr/bin/env bash
set -euo pipefail

# ==============================================================================
# Linux Infrastructure - Maintenance Script
# ==============================================================================
# Purpose: Periodically cleans logs and records a system metrics snapshot.
# Run by: systemd timer (infra-maintenance.timer) -> infra-maintenance.service
# Idempotent: Yes. Safe to run manually at any time.
# ==============================================================================

LOG_DIR="/var/log/infra-demo"
MAX_LOG_SIZE_KB=10240 # 10MB limit

echo "=== Maintenance Started: $(date -uIs) ==="

# 1. Log Rotation/Cleanup
if [ ! -d "$LOG_DIR" ]; then
    echo "Warning: Log directory ${LOG_DIR} does not exist. Skipping log cleanup."
else
    echo "Checking log files in ${LOG_DIR} for rotation/cleanup..."
    
    # Process log files in the target directory
    for log_file in "${LOG_DIR}"/*.log; do
        # Ensure it's a real file (handles empty glob)
        if [ -f "${log_file}" ]; then
            file_size=$(du -k "${log_file}" | cut -f1)
            if [ "${file_size}" -gt "${MAX_LOG_SIZE_KB}" ]; then
                echo "Log file ${log_file} (${file_size} KB) exceeds limit (${MAX_LOG_SIZE_KB} KB). Truncating..."
                
                # Keep the last 5000 lines of the log file to avoid disk exhaustion
                tail -n 5000 "${log_file}" > "${log_file}.tmp"
                mv "${log_file}.tmp" "${log_file}"
                chmod 640 "${log_file}"
                
                # If infra_user and infra_group exist, restore ownership
                if id "infra_user" &>/dev/null; then
                    chown infra_user:infra_group "${log_file}"
                fi
                echo "Log file ${log_file} truncated successfully."
            else
                echo "Log file ${log_file} (${file_size} KB) is within limits."
            fi
        fi
    done
fi

# 2. System Resource Snapshot
echo ""
echo "--- System Snapshot ---"
echo "Host Uptime:      $(uptime -p 2>/dev/null || uptime)"
echo "CPU Load Average: $(cat /proc/loadavg 2>/dev/null || echo 'N/A')"
echo ""
echo "Memory Usage:"
free -h || echo "N/A"
echo ""
echo "Disk Usage (Root filesystem):"
df -h / || echo "N/A"
echo ""

# 3. Service Status Check
echo "--- Service Status ---"
if systemctl list-units --full --all | grep -Fq 'infra-demo.service'; then
    if systemctl is-active --quiet infra-demo; then
        echo "infra-demo.service: ACTIVE (Running)"
    else
        echo "infra-demo.service: INACTIVE (Stopped/Failed)"
    fi
else
    echo "infra-demo.service: NOT INSTALLED"
fi

echo "=== Maintenance Completed: $(date -uIs) ==="
