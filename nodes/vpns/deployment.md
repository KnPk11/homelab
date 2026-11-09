# VPNs-87 Master Bootstrap Guide

This node (`vpns`, `192.168.50.87`, Proxmox CT 108) is the dedicated **remote access gateway and Tailscale subnet router**.

This node operates on a strict **Infrastructure as Intent** methodology. Do not edit tracked configurations directly on the server. Instead, push updates to Git, pull them on the server (`auto_pull_repo.sh`), and re-run service deployment steps.

**Secrets are not in Git.** The Tailscale node state lives under `/var/lib/tailscale/tailscaled.state`. After a nuke-and-pave, restore that state file (or re-authenticate with a Tailscale auth key) before services will work.

---

## 1. System Bootstrap & Scripts

*   Follow the **[Universal Node Bootstrap Guide](../../shared/docs/universal-node-bootstrap.md)** to install prerequisites and link this node to GitOps.
*   **Cron Offset:** Set the `auto_pull_repo.sh` cronjob to run at minute **17** to stagger network load:
    ```bash
    (crontab -l 2>/dev/null; echo "17 * * * * /opt/homelab-repo/shared/scripts/auto_pull_repo.sh >> /var/log/auto_pull.log 2>&1") | sort -u | crontab -
    ```

---

## 2. Services on this Node

| Service | Protocol / Mode | Role | Runbook |
| :--- | :--- | :--- | :--- |
| **Tailscale Subnet Router** | WireGuard Mesh | Advertises `192.168.50.0/24`, `192.168.88.0/24` | [deployment.md](services/tailscale/deployment.md) |
| **SSH Doorbell** | PAM `sshd` | Observability Telegram alert | [deployment.md](../../shared/observability/ssh-doorbell/deployment.md) |

---

## 3. Related Documentation

*   [Tailscale Architecture & Security Setup](../../docs/02_Services/tailscale/setup.md)
