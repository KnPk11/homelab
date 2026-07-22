# Proxmox Backup Server (PBS) LXC Deployment Guide

> [!NOTE]
> **Tags:** #Proxmox #PBS #Backup #LXC #Infrastructure

This document details the deployment, storage pass-through, and Proxmox VE integration for the dedicated **Proxmox Backup Server (PBS)** LXC container (`pbs` / CT 109 / `[PBS-IP]`).

## 🏗️ Architecture Overview

| Property | Value |
| :--- | :--- |
| **Hostname** | `pbs` |
| **Container ID** | `109` |
| **IP Address** | `[PBS-IP]/24` |
| **Gateway** | `[GATEWAY-IP]` |
| **Base OS** | Debian 12 (Bookworm) Standard LXC Template |
| **Type** | Unprivileged Container (`nesting=1`, `protection=1`) |
| **Port** | `8007` (HTTPS Web UI / API endpoint) |
| **Storage Location (Linux)** | `/mnt/newdrive/pbs-datastore` (Host) ➔ `/mnt/datastore/pbs` (LXC Mount Point `mp0`) |
| **Storage Location (Windows)** | `/mnt/newdrive/pbs-windows-datastore` (Host) ➔ `/mnt/datastore/pbs-windows` (LXC Mount Point `mp1`) |

## 🛠️ Step-by-Step Deployment Procedure

### 1. Provision LXC Container (Debian 12 Bookworm)
Proxmox Backup Server v3 requires Debian 12 (Bookworm) dependencies (`libapt-pkg6.0`, `libsgutils2-1.46-2`).

On `proxmox-host` (`[PROXMOX-HOST-IP]`):
```bash
pct create 109 local:vztmpl/debian-12-standard_12.12-1_amd64.tar.zst \
  --hostname pbs \
  --cores 2 \
  --memory 1024 \
  --swap 512 \
  --net0 name=eth0,bridge=vmbr0,firewall=1,ip=[PBS-IP]/24,gw=[GATEWAY-IP] \
  --storage local-lvm \
  --rootfs local-lvm:8 \
  --features nesting=1 \
  --onboot 1 \
  --protection 1 \
  --unprivileged 1

pct start 109
```

### 2. Storage Bind-Mounts & Permissions
Bind-mount dedicated backup storage directories from the host into LXC 109.

1. Create storage directories on the Proxmox host:
   ```bash
   mkdir -p /mnt/newdrive/pbs-datastore /mnt/newdrive/pbs-windows-datastore
   # Unprivileged LXC subuid shift: UID 34 (backup) inside LXC maps to UID 100034 on host
   chown -R 100034:100034 /mnt/newdrive/pbs-datastore /mnt/newdrive/pbs-windows-datastore
   ```

2. Add mount points `mp0` and `mp1` to LXC 109:
   ```bash
   pct set 109 --protection 0
   pct set 109 -mp0 /mnt/newdrive/pbs-datastore,mp=/mnt/datastore/pbs
   pct set 109 -mp1 /mnt/newdrive/pbs-windows-datastore,mp=/mnt/datastore/pbs-windows
   pct set 109 --protection 1
   ```

3. Verify ownership inside the LXC:
   ```bash
   pct exec 109 -- chown -R backup:backup /mnt/datastore/pbs /mnt/datastore/pbs-windows
   ```

### 3. Install Proxmox Backup Server Packages
On `pbs` (`[PBS-IP]`):

1. Add Proxmox release GPG keyring:
   ```bash
   # Copy GPG keyring from host or download proxmox-release-bookworm.gpg
   cp /etc/apt/trusted.gpg.d/proxmox-* /etc/apt/trusted.gpg.d/
   ```

2. Add `pbs-no-subscription` repository:
   ```bash
   echo "deb http://download.proxmox.com/debian/pbs bookworm pbs-no-subscription" > /etc/apt/sources.list.d/pbs-install.list
   apt-get update
   ```

3. Install `proxmox-backup-server`:
   ```bash
   DEBIAN_FRONTEND=noninteractive apt-get install -y proxmox-backup-server
   ```

4. Verify service status:
   ```bash
   systemctl status proxmox-backup-proxy.service
   ```

### 4. Datastore & API Token Configuration
Inside the `pbs` LXC (`[PBS-IP]`):

1. **Create Datastores (`pbs-linux` & `pbs-windows`)**:
   ```bash
   proxmox-backup-manager datastore create pbs-linux /mnt/datastore/pbs
   proxmox-backup-manager datastore create pbs-windows /mnt/datastore/pbs-windows
   ```

2. **Create API User & Token**:
   ```bash
   proxmox-backup-manager user create pve-backup@pbs --comment "PVE Automated Backup User"
   proxmox-backup-manager user generate-token pve-backup@pbs pve-token --comment "PVE Token"
   ```

3. **Grant ACL Permissions**:
   ```bash
   proxmox-backup-manager acl update /datastore/pbs-linux DatastoreAdmin --auth-id 'pve-backup@pbs'
   proxmox-backup-manager acl update /datastore/pbs-linux DatastoreAdmin --auth-id 'pve-backup@pbs!pve-token'
   proxmox-backup-manager acl update /datastore/pbs-windows DatastoreAdmin --auth-id 'pve-backup@pbs'
   proxmox-backup-manager acl update /datastore/pbs-windows DatastoreAdmin --auth-id 'pve-backup@pbs!pve-token'
   ```

4. **Fetch Certificate Fingerprint**:
   ```bash
   proxmox-backup-manager cert info | grep -i fingerprint
   ```

### 5. Proxmox VE Storage Integration
On `proxmox-host` (`[PROXMOX-HOST-IP]`), register both PBS storage endpoints:

```bash
pvesm add pbs pbs-linux \
  --server [PBS-IP] \
  --datastore pbs-linux \
  --username 'pve-backup@pbs!pve-token' \
  --password '<API_TOKEN_VALUE>' \
  --fingerprint '<SHA256_FINGERPRINT>'

pvesm add pbs pbs-windows \
  --server [PBS-IP] \
  --datastore pbs-windows \
  --username 'pve-backup@pbs!pve-token' \
  --password '<API_TOKEN_VALUE>' \
  --fingerprint '<SHA256_FINGERPRINT>'
```

Verify status:
```bash
pvesm status
```
*Expected Output:* Both `pbs-linux` and `pbs-windows` statuses are `active`.

## 🧪 Verification & Backup Test

Run an immediate snapshot backup of a guest container (e.g. CT 107 `pulse`):

```bash
vzdump 107 --storage pbs-linux --mode snapshot
```

## 🔒 Client-Side AES-256 Encryption

Proxmox Backup Server supports **Client-Side AES-256-GCM Zero-Knowledge Encryption**.

* **Client-Side Security**: Encryption takes place on the Proxmox VE host **before** backup data leaves over the network. The PBS server receives and stores only unreadable encrypted ciphertext.
* **How to Enable**:
  1. Open Proxmox VE Web UI ➔ **Datacenter ➔ Storage ➔ `pbs-storage` ➔ Edit**.
  2. Under **Encryption**, select **Auto-generate a new key**.
  3. Click **Save**.
* **Key Preservation**: Proxmox VE will prompt you to download the **Encryption Key file** and **Paper Key**. Save this key in Bitwarden / password manager / offline vault. Without this key, encrypted backups cannot be decrypted if the Proxmox host is lost.

## 🛡️ Service Hardening & Best Practices

1. **Change Default Root Password (PRIORITY #1)**:
   * Change the temporary root password (`[TEMPORARY-PASSWORD]`) to your master password via `passwd root` inside the LXC or via the PBS Web UI (**Access Control ➔ User Management ➔ Change Password**).
2. **Direct LAN/VPN Access (No Public Reverse Proxy)**:
   * Hypervisors (Proxmox VE `:8006`) and backup infrastructure (PBS `:8007`) operate directly over native ports on private LAN/VPN (`192.168.x.x`).
   * **Why avoid reverse-proxying core hypervisors**:
     1. **Eliminates Circular Dependencies**: Ensures management UI access remains 100% operational even if guest reverse proxy containers (Caddy) are down.
     2. **Zero Public Domain Exposure**: Prevents public DNS/subdomain probes and keeps hypervisor management endpoints completely hidden from WAN scanners.
3. **Firewall Restrictions (`109.fw`)**:
   * Restrict inbound access on TCP port `8007` exclusively to trusted subnets (`main-lan`, `vpn-net`, `homelab-lan`).
4. **Offsite Backup & Off-Server Copy**:
   * **The `rsync` Incremental Chunk Advantage**:
     * `scp` is a full-copy tool that blindly re-transfers the entire 43 GB datastore every single time.
     * `rsync` scans the `.chunks/` folder and **ONLY transfers new or modified 4MB chunks**. After the initial sync, daily offsite transfers finish in **seconds** (transferring ~50 MB instead of 43 GB)!
   * **Commands**:
     ```bash
     # Recommended rsync command (Git Bash / WSL / Linux / Mac - INCREMENTAL & FAST):
     rsync -avzP root@[PROXMOX-HOST-IP]:/mnt/newdrive/pbs-datastore/ "/c/Users/[USER]/Desktop/pbs"

     # Fallback SCP command (Native Windows PowerShell - full re-download each run):
     scp -r root@[PROXMOX-HOST-IP]:/mnt/newdrive/pbs-datastore/ "C:\Users\[USER]\Desktop\pbs"
     # Or connecting directly to the PBS LXC ([PBS-IP]):
     scp -r root@[PBS-IP]:/mnt/datastore/pbs/ "C:\Users\[USER]\Desktop\pbs"
     ```
   * Alternatively, use PBS built-in **Remote Sync Jobs** if the destination PC also runs PBS.
5. **Two-Factor Authentication (2FA / TOTP) [Optional]**:
   * For LAN-only homelabs protected by strong passwords and Proxmox firewall rules, 2FA is optional. If desired for WAN or high-security setups, enable TOTP under **Access Control ➔ Two-Factor Authentication**.




