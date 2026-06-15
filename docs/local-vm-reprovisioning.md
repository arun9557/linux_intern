# 💻 How to Reprovision Your Local VM (From Scratch!)

Hey! If you want to test my provisioning scripts from a completely clean slate, here is a quick guide on how I set up my VM, take snapshots, and roll them back. This is super useful for testing if the script is actually idempotent (running it multiple times without breaking things).

---

## 💿 1. Setting Up Your VM
I'm using **VirtualBox** (but you can use VMware too) with **Ubuntu Server 24.04 LTS**.

1. **Allocated Resources**: I gave the VM **2 vCPUs**, **2 GB RAM**, and a **20 GB Virtual Hard Disk** (that's plenty for this project).
2. **Network settings**: I configured a NAT network with these **Port Forwarding rules** so I can access the VM from my host machine:
   - **SSH**: Host Port `2222` -> Guest Port `22`
   - **App Service**: Host Port `8080` -> Guest Port `8080`
3. **OS Install**: Did a minimal install, enabled OpenSSH, and created a default user named `ubuntu` (or whatever admin name you want).

---

## 📸 2. Taking a Clean Snapshot (Don't skip this!)
Before you run any scripts, take a snapshot of the clean VM state. This way, if you make a mistake, you can reset it instantly instead of reinstalling the whole OS.

1. Turn off your VM: `sudo poweroff`
2. In VirtualBox/VMware, select your VM, go to the **Snapshots** tab, and click **Take**.
3. Name it something like `Clean OS Installed`.
4. Turn the VM back on.

---

## 🚀 3. Running & Rerunning the Setup

Once you're in the VM, clone the repo and run:

```bash
git clone https://github.com/arun9557/linux_intern.git
cd linux_intern/
chmod +x scripts/*.sh
sudo ./scripts/provision.sh
```

### Testing Idempotency
To make sure my script is bulletproof:
1. Run `sudo ./scripts/provision.sh` again.
2. It should finish in a few seconds because it detects that `infra_user` is already created, UFW rules are already active, and configurations are already in place.
3. Validate everything is still fine: `sudo ./scripts/validate.sh`.

---

## 🔄 4. Rolling Back to Clean State
If you want to test everything on a fresh slate again:
1. Shut down the VM.
2. Open VirtualBox, go to **Snapshots**, select `Clean OS Installed`, and click **Restore**.
3. Turn the VM back on. You're back to a fresh installation!
