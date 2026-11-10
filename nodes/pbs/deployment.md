# pbs: Master Bootstrap Guide

> **Hostname:** `pbs` | **IP:** `192.168.50.86` | **Proxmox:** CT 109 | **Type:** Proxmox LXC (Proxmox Backup Server)

This node (`pbs`, `192.168.50.86`, Proxmox CT 109) is the dedicated **Proxmox Backup Server** instance providing deduplicated backup storage for the cluster and workstations.

This node operates on a strict **Infrastructure as Intent** methodology. Do not edit tracked configurations directly on the server. Instead, push updates to Git, pull them on the server (`auto_pull_repo.sh`), and re-run service deployment steps.

**Secrets are not in Git.** Real configuration files, TLS certificates, and user keys live under `/etc/proxmox-backup/`. After a nuke-and-pave, restore those from the secrets vault before services will work.

---

## 1. System Bootstrap & Scripts

*   Follow the **[Universal Node Bootstrap Guide](../../shared/docs/universal-node-bootstrap.md)** to install prerequisites and link this node to GitOps.
*   **Cron Offset:** Set the `auto_pull_repo.sh` cronjob to run at minute **38** to stagger network load:
    ```bash
    (crontab -l 2>/dev/null; echo "38 * * * * /opt/homelab-repo/shared/scripts/auto_pull_repo.sh >> /var/log/auto_pull.log 2>&1") | sort -u | crontab -
    ```

---

## 2. Services on this Node

| Service | Port / Protocol | Role | Runbook |
| :--- | :--- | :--- | :--- |
| **Proxmox Backup Server** | 8007 (HTTPS) | Deduplicated guest & client backup storage | [deployment.md](services/pbs/deployment.md) |
| **SSH Doorbell** | PAM `sshd` | Observability Telegram alert | [deployment.md](../../shared/observability/ssh-doorbell/deployment.md) |

---

## 3. Related Infrastructure & Specs

*   [PBS Proxmox LXC Spec](../../docs/00_Infrastructure/proxmox/pbs-lxc.md) — Container provisioning, resource limits, and bind mounts.
*   [PBS Architecture & Retention Guide](../../docs/00_Infrastructure/proxmox/proxmox-backup-server.md) — Retention models, garbage collection, and client setups.
