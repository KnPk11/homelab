# Proxmox Backup Server (PBS) Service Deployment

> **Location:** `nodes/pbs/services/pbs/deployment.md`  
> **Node:** `pbs` (`192.168.50.86`, Proxmox CT 109)

## 1. Overview & Architecture

Proxmox Backup Server provides deduplicated, compressed, and encrypted backups for Proxmox VE VMs, LXC containers, and physical clients.

* **Primary Daemons:** `proxmox-backup.service`, `proxmox-backup-proxy.service`.
* **Port / Protocol:** TCP `8007` (HTTPS / API).
* **Datastores:**
  * `/mnt/datastore/pbs` — Primary datastore for Proxmox VE guest backups.
  * `/mnt/datastore/pbs-windows` — Secondary datastore for workstation client backups.

---

## 2. Secrets & Persistent Configuration

All persistent configuration and cryptographic material lives in `/etc/proxmox-backup/`:

| Path | Purpose |
| :--- | :--- |
| `/etc/proxmox-backup/datastore.cfg` | Datastore definitions, paths, and retention policies |
| `/etc/proxmox-backup/user.cfg` | User accounts, API tokens, and ACLs |
| `/etc/proxmox-backup/proxy.key` / `.pem` | TLS certificates for the web interface and API |
| `/etc/proxmox-backup/authkey.key` | Internal authentication token signing key |

---

## 3. Deployment & Restoration Procedure

### A. Host Storage Mounts & UID Mapping (Run on Proxmox Host)
Because PBS runs in an unprivileged LXC, UID 34 (`backup`) maps to UID 100034 on the host:
```bash
# On Proxmox Host (pve1):
mkdir -p /mnt/newdrive/pbs-datastore /mnt/newdrive/pbs-windows-datastore
chown -R 100034:100034 /mnt/newdrive/pbs-datastore /mnt/newdrive/pbs-windows-datastore

# Verify mountpoints on CT 109:
# mp0: /mnt/newdrive/pbs-datastore,mp=/mnt/datastore/pbs
# mp1: /mnt/newdrive/pbs-windows-datastore,mp=/mnt/datastore/pbs-windows
```

### B. Package Installation (Inside `pbs` CT)
If rebuilding from bare Debian LXC:
```bash
# Add Proxmox Backup No-Subscription Repository:
echo "deb http://download.proxmox.com/debian/pbs bookworm pbs-no-subscription" > /etc/apt/sources.list.d/pbs.list
apt update && apt install -y proxmox-backup-server
```

### C. Restore Configuration & Start Services
Restore the `/etc/proxmox-backup/` configuration tree from the offline secrets vault:
```bash
sudo cp -r /path/to/vault/pbs/proxmox-backup/* /etc/proxmox-backup/
sudo chown -R backup:backup /etc/proxmox-backup/ /mnt/datastore/
sudo systemctl restart proxmox-backup.service proxmox-backup-proxy.service
```

---

## 4. Health Verification & Status

```bash
# Check service status
systemctl status proxmox-backup-proxy.service

# List active datastores and verify usage
proxmox-backup-manager datastore list

# View overall server status & task logs
proxmox-backup-manager status
```
