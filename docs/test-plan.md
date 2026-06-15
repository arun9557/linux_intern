# Test Execution Plan

This document maps out the milestones and testing procedures to verify the correctness, idempotency, and security of the provisioning process.

---

## 1. Test Matrix & Scenarios

| Test Case | Description | Procedure | Expected Results |
| :--- | :--- | :--- | :--- |
| **TC-01: Clean Setup** | Verify provisioning runs successfully on a fresh, clean VM. | Restore VM snapshot, run `sudo ./scripts/provision.sh`. | Returns exit code 0. Deploys services, creates users, configures firewall. |
| **TC-02: Idempotency Rerun** | Verify running the script twice does not cause duplicate configurations. | Run `sudo ./scripts/provision.sh` immediately after TC-01 completes. | Returns exit code 0. No duplicate entries in sudoers, users, or systemd units. |
| **TC-03: User Sudoers Verification** | Verify user `infra_user` exists and can run sudo commands passwordlessly. | Run `sudo -u infra_user sudo -n whoami`. | Outputs `root` without prompting for a password. |
| **TC-04: HTTP Health Endpoint** | Verify the Python service correctly responds with expected JSON payload. | Run `curl -i http://localhost:8080/health`. | Returns HTTP 200 OK. JSON contains `"status": "healthy"` and dynamically updated `"uptime"`. |
| **TC-05: Port Exposure & UFW** | Verify only port 22 and port 8080 are accessible externally. | Run `sudo ufw status` and check active ports with `ss -tulpn`. | UFW shows status active. Ports 22 and 8080 allowed. All other incoming ports denied. |
| **TC-06: Maintenance Timer Trigger**| Verify the maintenance timer trigger runs the maintenance service. | Run `sudo systemctl status infra-maintenance.timer` and run service manually. | Timer shows active. Manual execution completes and writes to `/var/log/infra-demo/maintenance.log`. |
| **TC-07: Log Visibility & Routing** | Verify logs are correctly routed to files and systemd journal. | Query `journalctl -u infra-demo` and inspect `/var/log/infra-demo/app.log`. | Both show recent HTTP request logs. |
| **TC-08: Reboot Survival** | Verify all services start up automatically and validation passes post-reboot. | Reboot VM via `sudo reboot`, wait, then run `./scripts/validate.sh`. | Validation script returns SUCCESS (Exit Code 0). |

---

## 2. Manual Test Execution Walkthrough

### Step 1: Execute Provisioning
Run the provisioning script on your local VM:
```bash
sudo ./scripts/provision.sh
```
Check that the terminal outputs end with:
`=== Provisioning Completed Successfully ===`

### Step 2: Validate System State
Run the automated validation script:
```bash
./scripts/validate.sh
```
This script acts as the automated tester for **TC-02** through **TC-07**. The expected output is:
`Validation Status: SUCCESS` (with an exit code of `0`).

### Step 3: Test Passwordless Sudo
Execute:
```bash
sudo -u infra_user sudo -n whoami
```
*Expected Output*: `root`

### Step 4: Verify Maintenance Logs
Check if the maintenance snapshot script ran and logged successfully:
```bash
sudo cat /var/log/infra-demo/maintenance.log
```
*Expected Output*: Shows the timestamped logs with Uptime, memory usage, disk usage, and service status.

### Step 5: Reboot and Verify (Reboot Survival)
Run:
```bash
sudo reboot
```
After the VM boots back up, log in and run:
```bash
cd ~/linux-infra-intern-assignment
./scripts/validate.sh
```
Ensure all checks pass. Uptime check should dynamically show a small value (e.g. `< 60s`), demonstrating dynamic calculation.
