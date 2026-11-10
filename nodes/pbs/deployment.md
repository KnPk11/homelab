# pbs: Master Bootstrap Guide

> **Hostname:** `pbs` | **IP:** `192.168.50.86` | **Proxmox:** CT 109 | **Type:** Proxmox LXC (Proxmox Backup Server)

This node is the dedicated **Proxmox Backup Server (PBS)** instance providing deduplicated, compressed, and encrypted backups for the Proxmox cluster and client workstations.

This node operates on a strict **Infrastructure as Intent** methodology. Do not edit tracked configurations directly on the server. Instead, push updates to Git, pull them on the server (`auto_pull_repo.sh`), and re-run deployment steps.

**Secrets are not in Git.** Real configuration files, TLS certificates, and datastore definitions live under `/etc/proxmox-backup/`. After a nuke-and-pave, restore those from the secrets vault before services will work.

---

## 1. System Bootstrap

* Follow the **[Universal Node Bootstrap Guide](../../shared/docs/universal-node-bootstrap.md)** to install base prerequisites and link this node to GitOps.
* **Cron Offset:** Stagger `auto_pull_repo.sh` at minute **38**:
  ```bash
  (crontab -l 2>/dev/null; echo "38 * * * * /opt/homelab-repo/shared/scripts/auto_pull_repo.sh >> /var/log/auto_pull.log 2>&1") | sort -u | crontab -
  ```

---

## 2. Storage Bind-Mounts & UID Mapping

Because PBS runs in an unprivileged LXC, UID 34 (`backup`) maps to UID 100034 on the host:

```bash
# On Proxmox Host (pve1):
mkdir -p /mnt/newdrive/pbs-datastore /mnt/newdrive/pbs-windows-datastore
chown -R 100034:100034 /mnt/newdrive/pbs-datastore /mnt/newdrive/pbs-windows-datastore

# Ensure mount points exist on CT 109:
# mp0: /mnt/newdrive/pbs-datastore,mp=/mnt/datastore/pbs
# mp1: /mnt/newdrive/pbs-windows-datastore,mp=/mnt/datastore/pbs-windows
```

---

## 3. Secrets & Persistent Configuration

All persistent configuration and cryptographic material lives in `/etc/proxmox-backup/`:

| Path | Purpose |
| :--- | :--- |
| `/etc/proxmox-backup/datastore.cfg` | Datastore definitions, paths, and retention policies |
| `/etc/proxmox-backup/user.cfg` | User accounts, API tokens, and ACLs |
| `/etc/proxmox-backup/proxy.key` / `.pem` | TLS certificates for web interface (port 8007) & API |
| `/etc/proxmox-backup/authkey.key` | Internal authentication token signing key |

---

## 4. Deployment & Recovery Runbook

### A. Package Installation (If rebuilding bare Debian LXC)
```bash
echo "deb http://download.proxmox.com/debian/pbs bookworm pbs-no-subscription" > /etc/apt/sources.list.d/pbs.list
apt update && apt install -y proxmox-backup-server
```

### B. Restore Configuration & Start Services
Restore the `/etc/proxmox-backup/` configuration tree from the offline secrets vault:
```bash
sudo cp -r /path/to/vault/pbs/proxmox-backup/* /etc/proxmox-backup/
sudo chown -R backup:backup /etc/proxmox-backup/ /mnt/datastore/
sudo systemctl restart proxmox-backup.service proxmox-backup-proxy.service
```

---

## 5. Health Verification

```bash
# Check service status (port 8007)
systemctl status proxmox-backup-proxy.service

# List active datastores and verify chunk storage usage
proxmox-backup-manager datastore list

# View overall backup server status & active task logs
proxmox-backup-manager status
```

---

## 6. Related Documentation & Services

* [PBS Proxmox LXC Sizing Spec](../../docs/00_Infrastructure/proxmox/pbs-lxc.md)
* [PBS Architecture & Retention Guide](../../docs/00_Infrastructure/proxmox/proxmox-backup-server.md)
* [SSH Doorbell](../../shared/observability/ssh-doorbell/deployment.md) — PAM `sshd` login alert to Homelab Watch
