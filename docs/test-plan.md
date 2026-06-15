# 🧪 My Testing Plan (How I Verified Everything)

Hey! This is my test execution plan. I wanted to make sure all parts of the provisioning flow work as expected, survive restarts, and keep the system secure.

Here's the plan I followed to test the VM!

---

## 📋 Test Scenarios

Here's my checklist of things to test, how I test them, and what the expected result is:

| Test Case | What it tests | How I run it | Expected Result |
| :--- | :--- | :--- | :--- |
| **TC-01: Clean Setup** | Checks if the provision script works on a fresh VM. | Restore snapshot, run `sudo ./scripts/provision.sh`. | Runs without errors, starts services, configures UFW. |
| **TC-02: Idempotency Rerun** | Checks if running the script twice breaks anything. | Run `sudo ./scripts/provision.sh` again immediately. | Skips existing config safely. No duplicates. |
| **TC-03: Sudo Permission** | Checks if `infra_user` has passwordless sudo rights. | Run `sudo -u infra_user sudo -n whoami`. | Outputs `root` without asking for a password. |
| **TC-04: API Response** | Checks if the Python app returns correct JSON data. | Run `curl -i http://localhost:8080/health`. | Returns `200 OK` and a JSON response with dynamic uptime. |
| **TC-05: Firewall Rules** | Checks if UFW is locking down the server. | Run `sudo ufw status`. | Shows only ports 22 and 8080 allowed. All others blocked. |
| **TC-06: Maintenance Timer**| Checks if log rotating works. | Run `sudo systemctl status infra-maintenance.timer`. | Shows timer is active and schedules tasks every 10 mins. |
| **TC-07: Log Files** | Checks if system logs are writing to file. | Check `/var/log/infra-demo/app.log`. | Shows recent requests logged properly. |
| **TC-08: Reboot Survival** | Checks if everything starts automatically after reboot. | Reboot the VM, then run `sudo ./scripts/validate.sh`. | All tests pass automatically. Uptime resets. |

---

## 🛠️ Step-by-Step Testing Walkthrough

### 1. Run the Provision Script
First, run this in your VM:
```bash
sudo ./scripts/provision.sh
```
Make sure you see `=== Provisioning Completed Successfully ===` at the end!

### 2. Run the Validator
Run the automated validation script to verify everything:
```bash
sudo ./scripts/validate.sh
```
It should print green `[ PASS ]` logs for every check and end with `Validation Status: SUCCESS`.

### 3. Verify Sudoers File
Check if the user `infra_user` can execute commands as root without a password:
```bash
sudo -u infra_user sudo -n whoami
```
It should print `root`.

### 4. Check the Maintenance Log
Check if the system snapshot was created successfully:
```bash
sudo cat /var/log/infra-demo/maintenance.log
```
You should see CPU, memory, and disk usage statistics logged with a timestamp.

### 5. Reboot Test
Restart the VM:
```bash
sudo reboot
```
Log back in, go to the folder, and run:
```bash
sudo ./scripts/validate.sh
```
Check if the validation status is still `SUCCESS`!
