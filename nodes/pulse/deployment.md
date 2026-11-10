# pulse: Master Bootstrap Guide

> **Hostname:** `pulse` | **IP:** `192.168.50.88` | **Proxmox:** CT 107 | **Type:** Proxmox LXC (Pulse Monitoring)

This node (`pulse`, `192.168.50.88`, Proxmox CT 107) is the **infrastructure monitoring appliance** hosting the Pulse dashboard.

This node operates on a strict **Infrastructure as Intent** methodology. Do not edit tracked configurations directly on the server. Instead, push updates to Git, pull them on the server (`auto_pull_repo.sh`), and re-run service deployment steps.

**Secrets are not in Git.** Real `.env` and encryption keys live under `/srv/pulse/` and `/etc/pulse/`. After a nuke-and-pave, restore those from the secrets vault before services will work.

---

## 1. System Bootstrap & Scripts

*   Follow the **[Universal Node Bootstrap Guide](../../shared/docs/universal-node-bootstrap.md)** to install prerequisites and link this node to GitOps.
*   **Cron Offset:** Set the `auto_pull_repo.sh` cronjob to run at minute **37** to stagger network load:
    ```bash
    (crontab -l 2>/dev/null; echo "37 * * * * /opt/homelab-repo/shared/scripts/auto_pull_repo.sh >> /var/log/auto_pull.log 2>&1") | sort -u | crontab -
    ```

---

## 2. Services on this Node

| Service | Port / Protocol | Role | Runbook |
| :--- | :--- | :--- | :--- |
| **Pulse** | 7655 (HTTP) | Proxmox cluster monitoring & alerting | [deployment.md](services/pulse/deployment.md) |
| **SSH Doorbell** | PAM `sshd` | Observability Telegram alert | [deployment.md](../../shared/observability/ssh-doorbell/deployment.md) |

---

## 3. Related Documentation

*   [Pulse Architectural Setup & Feature Notes](../../docs/02_Services/pulse/setup.md)
