# Local VM Reprovisioning Guide

This guide describes how to set up, clone, snapshot, and safely reprovision your local Virtual Machine (VM) to test deployment scripts in a clean state.

---

## 1. Initial VM Setup (Ubuntu Server 22.04/24.04 LTS)

1. **Download ISO**: Obtain the official ISO image for Ubuntu Server (22.04 LTS or 24.04 LTS).
2. **Create VM**:
   - In VirtualBox or VMware, create a new VM.
   - Allocate at least **2 vCPUs**, **2 GB RAM**, and a **20 GB Virtual Disk**.
   - Configure a network adapter as **Bridged** (to receive a local IP) or **NAT with Port Forwarding**:
     - Host Port `2222` -> Guest Port `22` (SSH)
     - Host Port `8080` -> Guest Port `8080` (Health Check Service)
3. **OS Installation**:
   - Proceed with standard installation options.
   - Create a temporary admin user (e.g. `ubuntu` or `sysadmin`).
   - Enable OpenSSH Server during installation.
   - Complete installation and reboot.

---

## 2. Setting Up the Git Repository on the Guest

To copy the project configuration files into the guest VM:
1. Log in to your VM via SSH:
   ```bash
   ssh -p 2222 ubuntu@localhost
   ```
2. Clone the repository into your home folder:
   ```bash
   git clone <your-repo-url> linux-infra-intern-assignment
   cd linux-infra-intern-assignment
   ```

---

## 3. Taking a Clean Snapshot (Crucial Step)

Before running the provisioning script, take a snapshot of the VM in its clean state. This allows you to quickly roll back and test the idempotency or script failures.

### In VirtualBox:
1. Shut down the VM: `sudo poweroff`
2. Select the VM in the VirtualBox Manager.
3. Click the menu next to the VM name and select **Snapshots**.
4. Click **Take**. Name it `Clean OS Installed`.
5. Start the VM again.

### In VMware Workstation / Player:
1. Shut down the VM.
2. Go to **VM** -> **Snapshot** -> **Take Snapshot**.
3. Name it `Clean OS Installed`.
4. Start the VM again.

---

## 4. Running the Provisioning Flow

Once the VM is running:
1. Navigate to the script directory:
   ```bash
   cd ~/linux-infra-intern-assignment
   ```
2. Execute the provisioning script as root (using sudo):
   ```bash
   sudo ./scripts/provision.sh
   ```
3. Observe the outputs. If successful, run the validation script to verify:
   ```bash
   ./scripts/validate.sh
   ```

---

## 5. Simulating Image Customization (Rerun Flow)

To test if the provisioning script is truly **idempotent**:
1. Run the provisioning script a second time:
   ```bash
   sudo ./scripts/provision.sh
   ```
2. Verify that:
   - No duplicate users are created.
   - Sudoers file permissions and values remain correct and are not appended repeatedly.
   - Systemd services do not crash or duplicate.
   - UFW firewall rules do not multiply.
3. Run the validation script again:
   ```bash
   ./scripts/validate.sh
   ```
   It should exit with `0` (Success).

---

## 6. Rolling Back to Clean State

To start over from a completely fresh state:
1. Shut down the VM: `sudo poweroff`
2. Select the VM in your virtualization tool.
3. Go to **Snapshots**.
4. Select the snapshot `Clean OS Installed` and click **Restore**.
5. Restart the VM. You are now back to the clean, pre-provisioned OS state.
