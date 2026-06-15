# Troubleshooting Guide

This guide describes common issues encountered during provisioning, service operations, and verification, and explains how to resolve them.

---

## 1. Permission and Sudo Issues

### Issue: `infra_user` is prompted for a password when running sudo commands
* **Cause**: Sudoers file `/etc/sudoers.d/infra_user` is either missing, has incorrect syntax, or incorrect permissions.
* **Resolution**:
  1. Log in as a root/admin user.
  2. Inspect permissions of `/etc/sudoers.d/infra_user` (must be `0440` owned by `root:root`). Fix with:
     ```bash
     sudo chown root:root /etc/sudoers.d/infra_user
     sudo chmod 0440 /etc/sudoers.d/infra_user
     ```
  3. Verify the file contains exactly:
     `infra_user ALL=(ALL) NOPASSWD: ALL`
  4. Test syntax correctness using visudo:
     ```bash
     sudo visudo -cf /etc/sudoers.d/infra_user
     ```

---

## 2. Systemd Service Startup Failures

### Issue: `infra-demo.service` is inactive (dead) or fails to start
* **Cause**: Python environment error, port conflicts, or directory permission problems.
* **Troubleshooting Steps**:
  1. Run `systemctl status infra-demo.service` to view basic status logs.
  2. Use journalctl to see detailed traceback logs:
     ```bash
     journalctl -u infra-demo.service --no-pager -n 50
     ```
  3. Ensure python3 is installed and the path `/usr/bin/python3` exists.
  4. Check if the port (default `8080`) is already bound by another service:
     ```bash
     sudo ss -tulpn | grep 8080
     ```
  5. Check file permissions on the service script and config environment:
     ```bash
     ls -l /opt/infra-demo/app.py
     ls -l /etc/infra-demo/infra-demo.env
     ```
     Ensure they are owned by `infra_user:infra_group`.

---

## 3. Log Redirection and Visibility Issues

### Issue: Logs are not appearing in `/var/log/infra-demo/app.log`
* **Cause**: Directory permissions prevent the service from writing, or the systemd version doesn't support the `append:` routing format.
* **Resolution**:
  1. Verify the service is active: `systemctl is-active infra-demo`
  2. Verify directory ownership: `/var/log/infra-demo` must be owned by `infra_user:infra_group` with mode `750`. Fix with:
     ```bash
     sudo chown -R infra_user:infra_group /var/log/infra-demo
     sudo chmod 750 /var/log/infra-demo
     ```
  3. Check systemd version: `systemctl --version`. If it is older than v240, standard output appending using `append:` syntax might not be supported. In this case, fall back to routing logs using standard shell redirection inside the ExecStart wrapper or upgrade your systemd installation. (Note: Ubuntu 22.04 and 24.04 support it natively).

---

## 4. Firewall / Network Connectivity Issues

### Issue: Unable to access port 8080 from the host machine or external clients
* **Cause**: UFW is blocking traffic, or the local VM network configuration is incorrect.
* **Resolution**:
  1. Run `sudo ufw status` and verify that port `8080/tcp` is allowed.
  2. Verify UFW rules are enabled: `sudo ufw status verbose`.
  3. If using VirtualBox/VMware, ensure you have set up **NAT port forwarding** correctly in your VM settings (Host Port `8080` -> Guest Port `8080`).
  4. Confirm the service is actually listening on `0.0.0.0` (all interfaces) rather than `127.0.0.1` (local loopback only). You can verify this with:
     ```bash
     sudo ss -tulpn | grep python3
     ```
     The output should show `*:8080` or `0.0.0.0:8080` (not `127.0.0.1:8080`).

---

## 5. Maintenance Timer Issues

### Issue: The system health snapshot is not updated in `/var/log/infra-demo/maintenance.log`
* **Cause**: The systemd timer is inactive or the maintenance script has syntax errors.
* **Resolution**:
  1. Check the timer status:
     ```bash
     systemctl status infra-maintenance.timer
     ```
  2. Verify the timer is scheduled to run next:
     ```bash
     systemctl list-timers --all
     ```
  3. Test manual execution of the maintenance task to verify the script is working:
     ```bash
     sudo systemctl start infra-maintenance.service
     ```
     Inspect `/var/log/infra-demo/maintenance.log` for any bash syntax errors output by the script execution.
