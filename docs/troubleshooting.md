# 🔧 Troubleshooting Guide (How to Fix Common Issues)

Hey! If you run into issues while setting up the project, don't worry. Here are some of the common errors I hit during development, what causes them, and how I fixed them.

---

## 🔑 1. Passwordless Sudo Issues
**Issue**: When I try to run a command as `infra_user` with sudo, it asks for a password.
- **Why it happens**: The sudoers config file under `/etc/sudoers.d/infra_user` either has syntax errors, incorrect owner, or too open file permissions.
- **How to fix**:
  1. Log in to your VM as an admin user.
  2. Check permissions on `/etc/sudoers.d/infra_user` (it must be `0440` and owned by `root:root`). To fix, run:
     ```bash
     sudo chown root:root /etc/sudoers.d/infra_user
     sudo chmod 0440 /etc/sudoers.d/infra_user
     ```
  3. Verify the file contains exactly this:
     `infra_user ALL=(ALL) NOPASSWD: ALL`
  4. Run `sudo visudo -cf /etc/sudoers.d/infra_user` to check for syntax errors.

---

## 🚀 2. Systemd Service Failures
**Issue**: `infra-demo.service` is inactive, dead, or refuses to start.
- **Why it happens**: Python environment configuration is broken, port 8080 is already in use, or permissions on the script files are wrong.
- **How to troubleshoot**:
  1. Check the service status:
     ```bash
     systemctl status infra-demo.service
     ```
  2. Inspect journalctl logs for trackbacks:
     ```bash
     journalctl -u infra-demo.service --no-pager -n 50
     ```
  3. Ensure another service isn't already using port 8080:
     ```bash
     sudo ss -tulpn | grep 8080
     ```
  4. Make sure `/opt/infra-demo/app.py` has executable permissions:
     ```bash
     ls -l /opt/infra-demo/app.py
     # If permissions are wrong, run:
     sudo chmod 750 /opt/infra-demo/app.py
     ```

---

## 📁 3. Logs Are Missing
**Issue**: I can't find `/var/log/infra-demo/app.log` or the file is empty.
- **Why it happens**: You're running the check as a non-root user who doesn't have read access to the `/var/log/infra-demo/` directory (which is restricted to `750`).
- **How to fix**:
  - Run the validator or read the logs with `sudo`:
    ```bash
    sudo cat /var/log/infra-demo/app.log
    ```
  - Double check directory permissions:
    ```bash
    sudo chown -R infra_user:infra_group /var/log/infra-demo
    sudo chmod 750 /var/log/infra-demo
    ```

---

## 🧱 4. Firewall Blocks Connection (UFW)
**Issue**: I cannot access the server's port 8080 or SSH port 22 from my host computer.
- **Why it happens**: The guest firewall is blocking the ports, or the local virtualization platform (VirtualBox/VMware) isn't forwarding them correctly.
- **How to fix**:
  1. Check UFW rules status:
     ```bash
     sudo ufw status
     ```
  2. If rules are active, make sure you allowed ports 22 and 8080.
  3. In VirtualBox/VMware, check your VM settings under **Network** -> **Advanced** -> **Port Forwarding**. Make sure you've mapped your host port (e.g. `8080`) to the VM's port (`8080`).
