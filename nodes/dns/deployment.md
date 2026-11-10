# dns: Master Bootstrap Guide

> **Hostname:** `dns` | **IP:** `192.168.50.102` | **Proxmox:** CT 106 | **Type:** Proxmox LXC (AdGuard Home)

This node operates on a strict **Infrastructure as Intent** methodology. Do not edit tracked config directly on the server. Instead, push updates to Git, pull them on the server (`auto_pull_repo.sh`), and re-run the service deploy steps below.

**Secrets are not in Git.** Real env files live under `/srv/<service>/` so the clone at `/opt/homelab-repo` stays disposable. After a nuke-and-pave you must restore those from the secrets vault (or recreate from `*.env.example`) before services will work — a bare `git pull` is not enough.

If this machine ever suffers a catastrophic failure, follow the guides below in order.

## 1. System Bootstrap

*   Follow the **[Universal Node Bootstrap Guide](../../shared/docs/universal-node-bootstrap.md)** to install prerequisites and link this node to GitOps.
*   **Cron Offset:** Set the `auto_pull_repo.sh` cronjob to run at minute **33** to stagger network load.

## 2. DNS Services

*   [AdGuardHome](services/adguard/deployment.md) — `/srv/adguard/`
