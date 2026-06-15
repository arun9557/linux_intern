# 🐧 Linux Infrastructure Intern - Take-Home Assignment
> **Project: Server Provisioning, Automation, and Basic Hardening Mini Lab**

Hey there! 👋 This is my submission for the Linux Infrastructure Take-Home Assignment. I built a fully automated, idempotent provisioning setup that turns a fresh Ubuntu Server (or Debian) VM into a secure, ready-to-go deployment environment. 

🎥 **Demo Video**: [Watch the Provisioning & Reboot Validation Demo on Google Drive](https://drive.google.com/file/d/1N0P0us80SqqLlsDUbDPm7tMXGfl-qSnB/view?usp=sharing)

Here's how everything is structured, how it works, and how to run it!

---

## 🛠️ How It Works (System Architecture)

Basically, here's what happens when you run my setup:

1. **Firewall (UFW)** blocks all incoming traffic by default, except for:
   - **Port 22** (so we can SSH in).
   - **Port 8080** (to access our Python health check service).
2. **OpenSSH** is hardened (no root login via password, secure login defaults).
3. **Python Health App** runs in the background as a systemd service (`infra-demo.service`) under a dedicated non-root user (`infra_user`).
   - It listens on port 8080 and returns a JSON response with the server status and dynamic uptime.
   - Systemd automatically routes all logs to `/var/log/infra-demo/app.log`.
4. **Maintenance Timer** (`infra-maintenance.timer`) runs a cron-like task every 10 minutes:
   - Cleans up and truncates log files if they grow past 10MB (to prevent disk full errors).
   - Appends a quick system resource snapshot (CPU, memory, disk usage) to `/var/log/infra-demo/maintenance.log`.

---

## 📁 Repository Structure

I organized the project files exactly like requested:

```text
linux-infra-intern-assignment/
├── README.md                          # You are here! (Project docs)
├── config/
│   └── infra-demo.env                 # Config file for app port and logs
├── scripts/
│   ├── provision.sh                   # The master script that sets up everything (Run as sudo)
│   ├── validate.sh                    # Automatically checks if everything is working fine
│   └── maintenance.sh                 # Log cleanup and system snapshot script
├── systemd/
│   ├── infra-demo.service             # Systemd service for the Python app
│   ├── infra-maintenance.service      # Systemd service for the maintenance script
│   └── infra-maintenance.timer        # Runs the maintenance task every 10 minutes
└── docs/
    ├── hardening-checklist.md         # Documentation of all security settings applied
    ├── local-vm-reprovisioning.md     # Quick guide on VM setup, snapshots, and cloning
    ├── test-plan.md                   # Test cases and manual verification guide
    └── troubleshooting.md             # Guide on how to fix common errors
```

---

## 🚀 How to Run the Project (Quick Start)

Make sure you're running this on a local VM (like VirtualBox or VMware running Ubuntu 22.04 or 24.04).

### Step 1: Clone this repo
```bash
git clone https://github.com/arun9557/linux_intern.git

cd linux_intern/
```

### Step 2: Make the scripts executable
```bash
chmod +x scripts/*.sh
```

### Step 3: Run the provision script
Run the main script with `sudo` to set up everything automatically:
```bash
sudo ./scripts/provision.sh
```
*(The script will install python3, ufw, setup the non-root user `infra_user` with passwordless sudo, configure directories, copy service files, set up firewall rules, and apply SSH hardening configurations).*

---

## 🧪 Verifying the Setup

I created an automated validation script that runs through all the checks to make sure the server is healthy:

```bash
./scripts/validate.sh
```

### What it checks:
- If `infra_user` exists and has proper passwordless sudo rights.
- Correct directory permissions (e.g. `/etc/infra-demo` and `/var/log/infra-demo` must be owned by `infra_user:infra_group` and restricted to `750`).
- If the Python health service is active and enabled.
- If querying `http://localhost:8080/health` returns HTTP 200 OK and a valid JSON response with dynamic uptime.
- If UFW firewall is active and blocking everything except ports 22 and 8080.
- If journalctl and local log files are readable.

*Tip: The validation script exits with `0` if all tests pass, or `1` if anything fails, making it perfect for CI/CD or automated reboot checks.*

---

## 🤖 AI Assistance & Verification Notes

As required by the assignment guidelines, here's how I used AI and what I manually verified myself:

### What AI helped me with:
- **Idempotency checks**: Helping write bash checks so the script doesn't append duplicate rules to `/etc/sudoers.d/infra_user` or `/etc/ssh/sshd_config` if it's run multiple times.
- **Systemd logging configurations**: Pointing out the newer `StandardOutput=append:/path/to/log` feature in Systemd (v240+) so we don't have to write messy redirection wrappers in the bash scripts.
- **Troubleshooting structure**: Laying out potential edge cases like UFW blocking VM port-forwarding on VirtualBox.

### What I manually verified:
- **Dynamic uptime**: Manually verified that the Python endpoint calculates actual uptime since startup rather than hardcoding it or fetching system-wide uptime.
- **Reboot survival**: Rebooted the local VM, verified that `infra-demo` comes back online immediately, and ran `./scripts/validate.sh` to get a clean `PASS` output.
- **Log truncation**: Verified that the maintenance script successfully trims large logs and doesn't crash if the log directory is empty.
