> [!NOTE]
> **Tags:** #Proxmox #PBS #Backup #LXC #Infrastructure

# Proxmox Backup Server (PBS) Deployment Guide

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

## 🧪 Verification & Automated Backup Verification Jobs

### 1. Manual Backup Test
Run an immediate snapshot backup of a guest container (e.g. CT 107 `pulse`):

```bash
vzdump 107 --storage pbs-linux --mode snapshot
```

### 2. Configure Automated PBS Verification Jobs (Verify Jobs)
Proxmox Backup Server features automated background **Verify Jobs** that cryptographically re-verify every stored data chunk on disk to guarantee zero data corruption or bitrot before you ever need to restore.

* **How to Configure in PBS Web UI**:
  1. Open PBS Web UI (`https://[PBS-IP]:8007`) ➔ Select your datastore (`pbs-linux` or `pbs-windows`).
  2. Click **Verify Jobs** ➔ **Add**.
  3. Set Schedule: e.g. `weekly` (e.g. `sat 03:00`).
  4. Set **Re-verify after (days)**: set to `30` days to periodically re-verify older chunks.
  5. Click **OK**.
* **CLI Setup (Inside PBS LXC `[PBS-IP]`)**:
  ```bash
  proxmox-backup-manager verify-job create verify-pbs-linux --store pbs-linux --schedule "sat 03:00"
  proxmox-backup-manager verify-job create verify-pbs-windows --store pbs-windows --schedule "sat 04:00"
  ```

## 🔒 Client-Side AES-256 Encryption

Proxmox Backup Server supports **Client-Side AES-256-GCM Zero-Knowledge Encryption**.

* **Client-Side Security**: Encryption takes place on the Proxmox VE host **before** backup data leaves over the network. The PBS server receives and stores only unreadable encrypted ciphertext.
* **How to Enable**:
  1. Open Proxmox VE Web UI ➔ **Datacenter ➔ Storage ➔ `pbs-storage` ➔ Edit**.
  2. Under **Encryption**, select **Auto-generate a new key**.
  3. Click **Save**.
* **Key Preservation & Offsite Backup**:
  * **Critical Requirement**: Save this key in your password manager / offline vault. Without this key, encrypted backups cannot be decrypted if the Proxmox host is lost.
  * **Downloading Key File via Windows PowerShell SCP**:
    ```powershell
    scp root@[PROXMOX-HOST-IP]:/etc/pve/priv/storage/pbs-linux.enc "C:\Users\[USER]\Desktop\pbs-linux-encryption-key.enc"
    ```

## 🛡️ Service Hardening & Best Practices

1. **Change Default Root Password (PRIORITY #1)**:
   * Change the temporary root password (`[TEMPORARY-PASSWORD]`) to your master password via `passwd root` inside the LXC or via the PBS Web UI (**Access Control ➔ User Management ➔ Change Password**).
2. **Two-Factor Authentication (2FA / TOTP) [Optional]**:
   * For LAN-only homelabs protected by strong passwords and Proxmox firewall rules, 2FA is optional. If desired for WAN or high-security setups, enable TOTP under **Access Control ➔ Two-Factor Authentication**.
3. **Direct LAN/VPN Access (No Public Reverse Proxy)**:
   * Hypervisors (Proxmox VE `:8006`) and backup infrastructure (PBS `:8007`) operate directly over native ports on private LAN/VPN (`192.168.x.x`).
   * **Why avoid reverse-proxying core hypervisors**:
     1. **Eliminates Circular Dependencies**: Ensures management UI access remains 100% operational even if guest reverse proxy containers (Caddy) are down.
     2. **Zero Public Domain Exposure**: Prevents public DNS/subdomain probes and keeps hypervisor management endpoints completely hidden from WAN scanners.
4. **Firewall Restrictions (`109.fw`)**:
   * Restrict inbound access on TCP port `8007` exclusively to trusted subnets (`main-lan`, `vpn-net`, `homelab-lan`).
5. **Offsite Backup & Off-Server Copy**:
   * **The `rsync` / WinSCP Incremental Chunk Advantage**:
     * `scp` is a full-copy tool that blindly re-transfers the entire datastore every single time.
     * `rsync` and **WinSCP Synchronize** scan the `.chunks/` folder and **ONLY transfer new or modified 4MB chunks**. After the initial sync, daily offsite transfers finish in **seconds** (transferring MBs instead of GBs)!
   * **WinSCP Graphical GUI Sync Method (Recommended for Windows)**:
     1. Open **WinSCP** ➔ Connect to `[PROXMOX-HOST-IP]` (`root`).
     2. Click **Commands ➔ Synchronize Checklist** (`Ctrl+S`).
     3. **Direction**: `Local` (Download from host to PC).
     4. **Target Directory**: `C:\Users\[USER]\Desktop\pbs-linux`
     5. **Comparison Criteria**: **`Modification time`** (Fast 2-second timestamp comparison).
     6. **Mirror files**: **Checked** (ensures deleted/pruned chunks on PBS are also removed from your PC backup to keep storage clean).
   * **FreeFileSync via Read-Only SMB Share Method (Alternative Windows GUI)**:
     1. Expose the datastore path `/mnt/newdrive/pbs-datastore` via Samba/SMB on Proxmox or NAS VM.
     2. **Critical Security Requirement**: Set the SMB share to **`read only = yes`**. This guarantees Windows can pull backups freely, but malware/ransomware on Windows can **never** modify, delete, or encrypt server backups!
     3. On Windows, open **FreeFileSync** ➔ Set Left: `\\[PROXMOX-HOST-IP]\pbs-linux` ➔ Set Right: `C:\Users\[USER]\Desktop\pbs-linux`.
     4. Select **Mirror** mode to sync new chunks and keep local PC backups tidy.
   * **CLI Commands (`rsync` / `scp`)**:
     ```bash
     # Recommended rsync command (Git Bash / WSL / Linux / Mac - INCREMENTAL & FAST):
     rsync -avzP root@[PROXMOX-HOST-IP]:/mnt/newdrive/pbs-datastore/ "/c/Users/[USER]/Desktop/pbs"

     # Fallback SCP command (Native Windows PowerShell - full re-download each run):
     scp -r root@[PROXMOX-HOST-IP]:/mnt/newdrive/pbs-datastore/ "C:\Users\[USER]\Desktop\pbs"
     # Or connecting directly to the PBS LXC ([PBS-IP]):
     scp -r root@[PBS-IP]:/mnt/datastore/pbs/ "C:\Users\[USER]\Desktop\pbs"
     ```
   * Alternatively, use PBS built-in **Remote Sync Jobs** if the destination PC also runs PBS.

---

## 🧹 Recommended Prune & Retention Policy (GFS Model)

Proxmox Backup Server utilizes chunk-level deduplication, allowing long-term historical retention with minimal disk space overhead.

### 1. Recommended Retention Parameters

| Parameter | Value | Purpose |
| :--- | :--- | :--- |
| **Keep Daily** | `7` | Retains 1 backup per day for 7 days for fast recent rollbacks. |
| **Keep Weekly** | `4` | Retains 1 backup per week for 4 weeks (~1 month of weekly checkpoints). |
| **Keep Monthly** | `6` | Retains 1 backup per month for 6 months for historical recovery. |
| **Keep Yearly** | `1` | Retains 1 end-of-year archive checkpoint. |

### 2. Configuration Steps

* **PBS Web UI**:
  1. Go to PBS Web UI (`https://[PBS-IP]:8007`) ➔ Select Datastore (`pbs-linux` / `pbs-windows`).
  2. Click **Prune & GC** ➔ **Edit Prune Options**.
  3. Set `keep-daily: 7`, `keep-weekly: 4`, `keep-monthly: 6`, `keep-yearly: 1`.
  4. Schedule automated **Prune Jobs** and **Garbage Collection (GC)** (e.g., weekly on Sundays at `03:00`).
* **CLI Setup (Inside PBS LXC `[PBS-IP]`)**:
  ```bash
  proxmox-backup-manager datastore update pbs-linux --keep-daily 7 --keep-weekly 4 --keep-monthly 6 --keep-yearly 1
  proxmox-backup-manager datastore update pbs-windows --keep-daily 7 --keep-weekly 4 --keep-monthly 6 --keep-yearly 1
  ```

---

## 📋 Proxmox VE Backup Job Best Practices

When creating or editing automated Backup Jobs in Proxmox VE (**Datacenter ➔ Backup ➔ Add/Edit Job**):

### 1. Notes Template Format
* **Recommended Template**: `{{guestname}} ({{vmid}})`
* **Why**: Generates clean, human-readable labels in PBS catalogs (e.g., `docker-services (100)` or `pulse (107)`). It makes identifying guest names and numerical IDs instant during restores.
* **Safe to Change**: Changing or updating the Notes Template only updates future backup metadata. It does **not** break deduplication or force a full re-upload.

### 2. Backup Fleecing Guidance
* **Default**: Keep **Fleecing Disabled** for local PBS setups.
* **Why**: When PBS runs locally on the host (`sata-ssd` / NVMe), backup speeds exceed 140+ MB/s, finishing snapshots in ~15 seconds without I/O latency bottlenecks.
* **When to Enable**: Enable Fleecing only if you run high-frequency transactional database VMs (e.g. PostgreSQL with heavy disk writes) or backup over a slow remote WAN link.






