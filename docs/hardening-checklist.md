# 🛡️ My Hardening Checklist (How I Secured the Server)

Hey! This is where I document all the security settings I applied to the server during the setup. I wanted to make sure the VM isn't just running the app, but is also locked down from common attacks.

Here's the breakdown of what I configured and why!

---

## 🔑 1. User & Sudo Access (Least Privilege)
I didn't want the app running as `root` because if someone exploits the Python app, they would get full root control of the system.

- **Created a custom user**: Created a non-root user `infra_user` under `infra_group`. The health check app and maintenance tasks run entirely under this user.
- **Sudoers File Config**: Added a clean configuration file under `/etc/sudoers.d/infra_user` with passwordless sudo privileges:
  `infra_user ALL=(ALL) NOPASSWD: ALL`
- **File Permissions**: Set the file permissions of `/etc/sudoers.d/infra_user` to `0440` (Read-only for owner/group, none for others) and made sure it's owned by `root:root`. This stops other local users from editing it.

---

## 🔒 2. SSH Daemon Hardening
For remote access, I set up some secure defaults inside `/etc/ssh/sshd_config.d/99-infra-hardening.conf` so the main configuration file remains clean.

| Setting | Value | Why I set this |
| :--- | :--- | :--- |
| `PermitRootLogin` | `prohibit-password` | Nobody can guess the root password remotely; they must use SSH keys. |
| `PasswordAuthentication` | `yes` | Kept as `yes` for easy debugging in VirtualBox, but in production, we should turn this off and use SSH Keys only. |
| `PermitEmptyPasswords` | `no` | Stops accounts without passwords from logging in over SSH. |
| `X11Forwarding` | `no` | Disables GUI forwarding over SSH to prevent UI exploits. |
| `MaxAuthTries` | `5` | Automatically kicks out connections after 5 failed login attempts to stop brute-forcing. |
| `ClientAliveInterval` | `300` | Sends a keep-alive check every 5 minutes. |
| `ClientAliveCountMax` | `2` | Drops the connection if the client doesn't respond after 10 minutes (keeps connections clean). |

---

## 🧱 3. Firewall Hardening (UFW)
I turned on Uncomplicated Firewall (UFW) with a **Default-Deny** incoming policy. If a port is not explicitly allowed, UFW drops the connection.

- **Default Incoming**: `Deny` (Nobody can access the VM unless allowed).
- **Default Outgoing**: `Allow` (The VM can fetch updates, logs, etc.).
- **Allowed Port 22/tcp**: Allows us to SSH into the VM.
- **Allowed Port 8080/tcp**: Allows external access to our Python health service.

---

## 📁 4. Strict File System Permissions
To stop unauthorized users from viewing configs or messing with our app, I locked down the directories:

- `/opt/infra-demo` (Contains app & scripts) -> Set to `750` (owner has full rights, group can read/execute, others get nothing). Owned by `infra_user:infra_group`.
- `/etc/infra-demo` (Contains config files) -> Set to `750`. Owned by `infra_user:infra_group`.
- `/var/log/infra-demo` (Contains logs) -> Set to `750`. Owned by `infra_user:infra_group`.
- `/etc/infra-demo/infra-demo.env` -> Set to `640` (Read/Write for owner, Read-only for group, others get nothing) to protect secret keys/config variables.

---

## ⚠️ What I Skipped (And Why)

1. **Changing SSH Port 22**: Usually, it's good practice to change the SSH port to something random (like `2222`), but I skipped this because VirtualBox NAT port forwarding gets messed up easily, and I didn't want to get locked out of my local VM.
2. **Disabling Password Authentication completely**: I left `PasswordAuthentication yes` so I can log in via VirtualBox console using standard username/password.
