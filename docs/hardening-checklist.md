# Security Hardening Checklist

This document details the security configurations applied during the provisioning phase of the Linux server environment and provides the rationale behind each decision.

## 1. Operating System & Package Level Hardening

| Check | Action Taken | Rationale | Status |
| :--- | :--- | :--- | :--- |
| **System Updates** | Ran `apt-get update` | Ensures the local package index is current before installs. | [x] Applied |
| **Minimal Tools** | Installed only `python3`, `ufw`, `curl`, `sudo`, `openssh-server` | Minimizes the attack surface by avoiding unnecessary software. | [x] Applied |

---

## 2. SSH Daemon Hardening

SSH hardening configurations are deployed in a modular config file `/etc/ssh/sshd_config.d/99-infra-hardening.conf` rather than modifying the main config directly.

| Setting | Configuration | Rationale | Status |
| :--- | :--- | :--- | :--- |
| **PermitRootLogin** | `prohibit-password` | Prevents remote root login via password, forcing key-based authentication. | [x] Applied |
| **PasswordAuthentication** | `yes` | Maintained for local VM ease of use. In production, this should be set to `no` once ssh keys are deployed. | [x] Applied (Safe default) |
| **PermitEmptyPasswords** | `no` | Prevents users with empty passwords from logging in over SSH. | [x] Applied |
| **X11Forwarding** | `no` | Disables GUI forwarding over SSH, preventing potential X11 hijacking exploits. | [x] Applied |
| **MaxAuthTries** | `5` | Limits brute-force login attempts before connection teardown. | [x] Applied |
| **ClientAliveInterval** | `300` | Sends a keepalive signal every 300 seconds to detect dead client sessions. | [x] Applied |
| **ClientAliveCountMax** | `2` | Terminates SSH sessions if client becomes unresponsive for 2 keepalive windows (10 minutes total). | [x] Applied |

---

## 3. Firewall Hardening (UFW)

The firewall is configured using Uncomplicated Firewall (UFW) to enforce a **Default-Deny** incoming policy.

| Direction | Port / Protocol | Target / Comment | Rationale | Status |
| :--- | :--- | :--- | :--- | :--- |
| **Default Incoming** | All | Deny | Protects the system from unauthorized network exposure. | [x] Applied |
| **Default Outgoing** | All | Allow | Allows the VM to fetch package updates, logs, etc. | [x] Applied |
| **Incoming** | `22/tcp` | SSH Daemon | Allows administrative shell access to the host. | [x] Applied |
| **Incoming** | `8080/tcp` | Health Demo App | Exposes the application port for monitoring and validation. | [x] Applied |

---

## 4. User and Sudo Privilege Isolation

| Security Measure | Implementation | Rationale | Status |
| :--- | :--- | :--- | :--- |
| **Least Privilege User** | Created `infra_user` with primary group `infra_group`. | Ensures the health app and maintenance tasks run as a non-privileged user instead of `root`. | [x] Applied |
| **Sudo Restriction** | Placed sudo rule in `/etc/sudoers.d/infra_user` | Avoids pollution of `/etc/sudoers` and limits changes to a clean modular config. | [x] Applied |
| **Strict File Permissions** | Set permissions of `/etc/sudoers.d/infra_user` to `0440` owned by `root:root`. | Prevents modification or reading of sudoers configuration by unauthorized users. | [x] Applied |

---

## 5. File System & Path Hardening

| Directory / File | Owner:Group | Mode (Octal) | Security Value | Status |
| :--- | :--- | :--- | :--- | :--- |
| `/opt/infra-demo` | `infra_user:infra_group` | `750` | Prevents other non-system users from reading/writing scripts. | [x] Applied |
| `/etc/infra-demo` | `infra_user:infra_group` | `750` | Restricts access to environment configuration files. | [x] Applied |
| `/var/log/infra-demo` | `infra_user:infra_group` | `750` | Protects operational log privacy. | [x] Applied |
| `/etc/infra-demo/infra-demo.env` | `infra_user:infra_group` | `640` | Protects config variables (potentially containing passwords/keys). | [x] Applied |

---

## 6. Intentionally Skipped Configurations

1. **Changing SSH Port 22**: Changing the SSH port was skipped because this environment runs on local VMs. Modifying the SSH port often breaks local VM NAT port forwarding rules configured in VirtualBox/VMware, leading to lockout.
2. **Disabling Password Authentication Completely**: Password authentication is kept enabled (`PasswordAuthentication yes`) because VM users rely on console password access. In a production cloud setting, this would be set to `no` in favor of public key authentication only.
