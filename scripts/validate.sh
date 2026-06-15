#!/usr/bin/env bash
set -euo pipefail

# ==============================================================================
# Linux Infrastructure - Validation Script
# ==============================================================================
# Purpose: Health-check utility verifying services, HTTP endpoint, firewall state,
#          users, permissions, log readability, and timer schedules.
# Returns: Exit 0 on absolute success, Exit 1 on any check failure.
# ==============================================================================

# Helper for colored output
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m' # No Color

FAILED=0

log_success() {
    echo -e "[ ${GREEN}PASS${NC} ] $1"
}

log_failure() {
    echo -e "[ ${RED}FAIL${NC} ] $1"
    FAILED=1
}

echo "=== System Validation Started ==="

# 1. Check OS Distribution
if [ -f /etc/os-release ]; then
    . /etc/os-release
    log_success "OS Check: Running on $PRETTY_NAME"
else
    log_failure "OS Check: Cannot read /etc/os-release"
fi

# 2. Check operational user existence
if id "infra_user" &>/dev/null; then
    log_success "User Check: User 'infra_user' exists"
else
    log_failure "User Check: User 'infra_user' does not exist"
fi

# 3. Check sudo configuration for infra_user
SUDOERS_FILE="/etc/sudoers.d/infra_user"
if [ -f "$SUDOERS_FILE" ]; then
    # Validate permissions
    mode=$(stat -c "%a" "$SUDOERS_FILE")
    owner=$(stat -c "%U:%G" "$SUDOERS_FILE")
    if [ "$mode" = "440" ] && [ "$owner" = "root:root" ]; then
        log_success "Sudoers Check: $SUDOERS_FILE has correct permissions ($mode) and ownership ($owner)"
    else
        log_failure "Sudoers Check: $SUDOERS_FILE has incorrect permissions/ownership ($mode, $owner)"
    fi
    # Check syntax / passwordless setting
    if grep -q "infra_user ALL=(ALL) NOPASSWD: ALL" "$SUDOERS_FILE"; then
        log_success "Sudoers Check: Passwordless sudo rule for 'infra_user' configured"
    else
        log_failure "Sudoers Check: Passwordless sudo rule not found in $SUDOERS_FILE"
    fi
else
    log_failure "Sudoers Check: File $SUDOERS_FILE does not exist"
fi

# 4. Check directories ownership & permissions
for dir in "/opt/infra-demo" "/etc/infra-demo" "/var/log/infra-demo"; do
    if [ -d "$dir" ]; then
        owner=$(stat -c "%U:%G" "$dir")
        mode=$(stat -c "%a" "$dir")
        if [ "$owner" = "infra_user:infra_group" ] && [ "$mode" = "750" ]; then
            log_success "Permissions Check: Directory $dir has correct permissions ($mode) and ownership ($owner)"
        else
            log_failure "Permissions Check: Directory $dir has incorrect permissions/ownership ($mode, $owner)"
        fi
    else
        log_failure "Permissions Check: Directory $dir does not exist"
    fi
done

# 5. Check Service Status (infra-demo)
if systemctl is-enabled --quiet infra-demo &>/dev/null; then
    log_success "Service Check: infra-demo.service is enabled"
else
    log_failure "Service Check: infra-demo.service is disabled"
fi

if systemctl is-active --quiet infra-demo &>/dev/null; then
    log_success "Service Check: infra-demo.service is active (running)"
else
    log_failure "Service Check: infra-demo.service is not running"
fi

# 6. Check HTTP Endpoint Response
PORT=8080
if [ -f "/etc/infra-demo/infra-demo.env" ]; then
    # Retrieve port from env file
    PORT=$(grep -oP '^PORT=\K\d+' /etc/infra-demo/infra-demo.env || echo 8080)
fi

echo "Querying HTTP Health endpoint on port $PORT..."
HTTP_RESPONSE=$(curl -s -i "http://localhost:$PORT/health" || true)

if [ -z "$HTTP_RESPONSE" ]; then
    log_failure "Health Endpoint: No response from HTTP health service on port $PORT"
else
    # Check HTTP Status Code
    STATUS_CODE=$(echo "$HTTP_RESPONSE" | grep "HTTP/" | awk '{print $2}')
    if [ "$STATUS_CODE" = "200" ]; then
        log_success "Health Endpoint: Returns HTTP 200 OK"
    else
        log_failure "Health Endpoint: Returns HTTP status code $STATUS_CODE (expected 200)"
    fi
    
    # Check JSON body properties
    JSON_BODY=$(echo "$HTTP_RESPONSE" | tail -n 1)
    if echo "$JSON_BODY" | grep -q '"status": "healthy"'; then
        log_success "Health Endpoint: Response contains 'status': 'healthy'"
    else
        log_failure "Health Endpoint: Response does not contain 'status': 'healthy'. Body: $JSON_BODY"
    fi
    
    if echo "$JSON_BODY" | grep -q '"uptime"'; then
        uptime_val=$(echo "$JSON_BODY" | grep -oP '"uptime": \K\d+')
        log_success "Health Endpoint: Response contains uptime (Value: ${uptime_val}s)"
    else
        log_failure "Health Endpoint: Response does not contain 'uptime'. Body: $JSON_BODY"
    fi
fi

# 7. Check Firewall Configuration (UFW)
if ufw status | grep -q "Status: active"; then
    log_success "Firewall Check: UFW is active"
    # Check if SSH (22) and app port are open
    if ufw status | grep -q "22/tcp"; then
        log_success "Firewall Check: Port 22/tcp (SSH) is allowed"
    else
        log_failure "Firewall Check: Port 22/tcp (SSH) is not allowed"
    fi
    if ufw status | grep -q "$PORT/tcp"; then
        log_success "Firewall Check: Port $PORT/tcp is allowed"
    else
        log_failure "Firewall Check: Port $PORT/tcp is not allowed"
    fi
else
    log_failure "Firewall Check: UFW is inactive"
fi

# 8. Check Log Visibility
LOG_FILE="/var/log/infra-demo/app.log"
if [ -f "$LOG_FILE" ]; then
    log_success "Logs Check: Log file $LOG_FILE exists"
    if [ -s "$LOG_FILE" ]; then
        log_success "Logs Check: Log file is not empty. Recent line: $(tail -n 1 "$LOG_FILE")"
    else
        log_failure "Logs Check: Log file is empty"
    fi
else
    log_failure "Logs Check: Log file $LOG_FILE does not exist"
fi

if journalctl -u infra-demo --no-pager -n 5 &>/dev/null; then
    log_success "Logs Check: journalctl logs for 'infra-demo' are accessible and readable"
else
    log_failure "Logs Check: cannot read journalctl logs for 'infra-demo'"
fi

# 9. Check Maintenance Timer
if systemctl is-enabled --quiet infra-maintenance.timer &>/dev/null; then
    log_success "Timer Check: infra-maintenance.timer is enabled"
else
    log_failure "Timer Check: infra-maintenance.timer is disabled"
fi

if systemctl is-active --quiet infra-maintenance.timer &>/dev/null; then
    log_success "Timer Check: infra-maintenance.timer is active"
else
    log_failure "Timer Check: infra-maintenance.timer is inactive"
fi

echo "========================================="
if [ $FAILED -eq 0 ]; then
    echo -e "${GREEN}Validation Status: SUCCESS${NC}"
    exit 0
else
    echo -e "${RED}Validation Status: FAILED (Some checks failed)${NC}"
    exit 1
fi
