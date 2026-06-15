#!/usr/bin/env bash
set -euo pipefail

# ==============================================================================
# Linux Infrastructure - Provisioning Script
# ==============================================================================
# Purpose: Automatically configures the server environment: OS checks, user
#          creation, directory layout, service installation, security hardening.
# Compatibility: Ubuntu Server 22.04 / 24.04 LTS & Debian 12.
# Idempotent: Yes. Safe to run multiple times without duplicate configurations.
# ==============================================================================

# Ensure script is running as root
if [ "$EUID" -ne 0 ]; then
    echo "Error: This script must be run as root (or with sudo)." >&2
    exit 1
fi

echo "=== Provisioning Started ==="

# 1. OS/Distribution Detection
echo "Detecting OS..."
if [ -f /etc/os-release ]; then
    . /etc/os-release
    OS_NAME=$ID
    OS_VERSION=$VERSION_ID
    echo "Detected OS: $OS_NAME $OS_VERSION"
    if [[ "$OS_NAME" != "ubuntu" && "$OS_NAME" != "debian" ]]; then
        echo "Warning: Supported distributions are Ubuntu or Debian. Proceeding anyway..."
    fi
else
    echo "Error: Cannot detect OS release version (/etc/os-release missing)." >&2
    exit 1
fi

# 2. Package Updates & Installation
echo "Updating package index and installing required packages..."
apt-get update -y
apt-get install -y python3 ufw curl sudo openssh-server

# 3. Non-Root Sudo User Creation
USER_NAME="infra_user"
GROUP_NAME="infra_group"

echo "Configuring user and group..."
# Create group if it doesn't exist
if ! getent group "$GROUP_NAME" >/dev/null; then
    groupadd "$GROUP_NAME"
    echo "Group $GROUP_NAME created."
else
    echo "Group $GROUP_NAME already exists."
fi

# Create user if it doesn't exist
if ! id "$USER_NAME" &>/dev/null; then
    useradd -m -g "$GROUP_NAME" -s /bin/bash "$USER_NAME"
    echo "User $USER_NAME created."
else
    echo "User $USER_NAME already exists."
fi

# Configure passwordless sudo safely
echo "Configuring sudoers access..."
SUDOERS_FILE="/etc/sudoers.d/infra_user"
if [ ! -f "$SUDOERS_FILE" ] || [ "$(cat "$SUDOERS_FILE" 2>/dev/null)" != "${USER_NAME} ALL=(ALL) NOPASSWD: ALL" ]; then
    echo "${USER_NAME} ALL=(ALL) NOPASSWD: ALL" > "$SUDOERS_FILE"
    chmod 0440 "$SUDOERS_FILE"
    visudo -cf "$SUDOERS_FILE"
    echo "Passwordless sudo configured for ${USER_NAME}."
else
    echo "Sudoers file for ${USER_NAME} is already configured correctly."
fi

# 4. Service Directories Setup
echo "Creating application directories..."
APP_DIR="/opt/infra-demo"
CONF_DIR="/etc/infra-demo"
LOG_DIR="/var/log/infra-demo"

mkdir -p "$APP_DIR" "$CONF_DIR" "$LOG_DIR"

# Set ownership and permissions
chown -R "$USER_NAME":"$GROUP_NAME" "$APP_DIR" "$CONF_DIR" "$LOG_DIR"
chmod 750 "$APP_DIR" "$CONF_DIR" "$LOG_DIR"

# 5. Service Files & Configurations Deployment
echo "Deploying configuration file..."
cat << 'EOF' > "$CONF_DIR/infra-demo.env"
PORT=8080
LOG_PATH=/var/log/infra-demo/app.log
EOF
chown "$USER_NAME":"$GROUP_NAME" "$CONF_DIR/infra-demo.env"
chmod 640 "$CONF_DIR/infra-demo.env"

echo "Deploying Python health service application..."
cat << 'EOF' > "$APP_DIR/app.py"
#!/usr/bin/env python3
import os
import sys
import time
import json
from http.server import HTTPServer, BaseHTTPRequestHandler

# Record start time for uptime calculation
START_TIME = time.time()

class HealthCheckHandler(BaseHTTPRequestHandler):
    def log_message(self, format, *args):
        # Log to stdout in a format that journald can parse
        sys.stdout.write(f"[{self.log_date_time_string()}] {self.client_address[0]} - {format % args}\n")
        sys.stdout.flush()

    def do_GET(self):
        if self.path in ('/health', '/'):
            self.send_response(200)
            self.send_header('Content-Type', 'application/json')
            self.end_headers()
            
            uptime_seconds = int(time.time() - START_TIME)
            response = {
                "status": "healthy",
                "uptime": uptime_seconds,
                "timestamp": int(time.time())
            }
            self.wfile.write(json.dumps(response).encode('utf-8'))
        else:
            self.send_response(404)
            self.send_header('Content-Type', 'application/json')
            self.end_headers()
            response = {"error": "Not Found"}
            self.wfile.write(json.dumps(response).encode('utf-8'))

def main():
    # Load configuration from environment
    port = int(os.environ.get('PORT', 8080))
    server_address = ('', port)
    
    sys.stdout.write(f"Starting infra-demo HTTP server on port {port}...\n")
    sys.stdout.flush()
    
    try:
        httpd = HTTPServer(server_address, HealthCheckHandler)
        httpd.serve_forever()
    except Exception as e:
        sys.stderr.write(f"Server error: {e}\n")
        sys.stderr.flush()
        sys.exit(1)

if __name__ == '__main__':
    main()
EOF
chown "$USER_NAME":"$GROUP_NAME" "$APP_DIR/app.py"
chmod 750 "$APP_DIR/app.py"

echo "Deploying maintenance script..."
cat << 'EOF' > "$APP_DIR/maintenance.sh"
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

# 3. Check Service Status
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
EOF
chown "$USER_NAME":"$GROUP_NAME" "$APP_DIR/maintenance.sh"
chmod 750 "$APP_DIR/maintenance.sh"

# 6. Deploy Systemd Unit Files
echo "Deploying Systemd unit files..."
SYSTEMD_DEST="/etc/systemd/system"

# Demo Service
cat << 'EOF' > "$SYSTEMD_DEST/infra-demo.service"
[Unit]
Description=Infra Demo Python HTTP Health Service
After=network.target

[Service]
Type=simple
User=infra_user
Group=infra_group
EnvironmentFile=/etc/infra-demo/infra-demo.env
ExecStart=/usr/bin/python3 /opt/infra-demo/app.py
Restart=always
RestartSec=5
StandardOutput=append:/var/log/infra-demo/app.log
StandardError=append:/var/log/infra-demo/app.log
ProtectSystem=full
PrivateTmp=true
NoNewPrivileges=true

[Install]
WantedBy=multi-user.target
EOF

# Maintenance Service
cat << 'EOF' > "$SYSTEMD_DEST/infra-maintenance.service"
[Unit]
Description=Infra Maintenance Task Service
After=network.target

[Service]
Type=oneshot
User=infra_user
Group=infra_group
ExecStart=/bin/bash /opt/infra-demo/maintenance.sh
StandardOutput=append:/var/log/infra-demo/maintenance.log
StandardError=append:/var/log/infra-demo/maintenance.log
ProtectSystem=full
PrivateTmp=true
NoNewPrivileges=true
EOF

# Maintenance Timer
cat << 'EOF' > "$SYSTEMD_DEST/infra-maintenance.timer"
[Unit]
Description=Run Infra Maintenance Service every 10 minutes
Requires=infra-maintenance.service

[Timer]
Unit=infra-maintenance.service
OnCalendar=*:0/10
Persistent=true

[Install]
WantedBy=timers.target
EOF

# Reload Systemd daemon
echo "Reloading systemd daemon..."
systemctl daemon-reload

# Enable & Start services
echo "Enabling and starting service units..."
systemctl enable --now infra-demo.service
systemctl enable --now infra-maintenance.timer

# 7. Basic Hardening
echo "Applying security hardening..."

# SSH Hardening config directory & file setup
SSH_HARDENING_DIR="/etc/ssh/sshd_config.d"
SSH_HARDENING_FILE="${SSH_HARDENING_DIR}/99-infra-hardening.conf"
mkdir -p "$SSH_HARDENING_DIR"

cat << 'EOF' > "$SSH_HARDENING_FILE"
# Hardening configuration for SSH (Applied by provision.sh)
PermitRootLogin prohibit-password
PasswordAuthentication yes
PermitEmptyPasswords no
X11Forwarding no
MaxAuthTries 5
ClientAliveInterval 300
ClientAliveCountMax 2
EOF
chmod 644 "$SSH_HARDENING_FILE"

# Restart SSH daemon to safely pick up configurations (if running)
if systemctl is-active --quiet ssh; then
    systemctl restart ssh
    echo "SSH daemon restarted to apply hardening configurations."
elif systemctl is-active --quiet sshd; then
    systemctl restart sshd
    echo "SSHD daemon restarted to apply hardening configurations."
fi

# Firewall (UFW) configuration
echo "Configuring UFW firewall rules..."
ufw default deny incoming
ufw default allow outgoing

# Allow standard SSH and our application port
ufw allow 22/tcp comment 'Allow SSH'
ufw allow 8080/tcp comment 'Allow Demo HTTP health service'

# Enable UFW non-interactively
ufw --force enable
echo "UFW firewall configured and enabled."

echo "=== Provisioning Completed Successfully ==="
