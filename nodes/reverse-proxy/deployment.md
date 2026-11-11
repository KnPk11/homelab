# reverse-proxy: Master Bootstrap Guide

> **Hostname:** `reverse-proxy` | **IP:** `192.168.50.101` | **Proxmox:** CT 104 | **Type:** Proxmox LXC (Caddy / Ingress)

This node operates on a strict **Infrastructure as Intent** methodology. Do not edit tracked config directly on the server. Instead, push updates to Git, pull them on the server (`auto_pull_repo.sh`), and re-run the service deploy steps below.

**Secrets are not in Git.** Real `.env` / secret files live under `/srv/<service>/` so the clone at `/opt/homelab-repo` stays disposable. After a nuke-and-pave you must restore those from the secrets vault (or recreate from `*.env.example`) before services will work — a bare `git pull` is not enough.

If this machine ever suffers a catastrophic failure, follow the guides below in order.

## 1. System Bootstrap & Scripts

*   **Proxmox LXC Spec:** Review container allocation in **[Proxmox LXC Spec](../../docs/00_Infrastructure/proxmox/guests/reverse-proxy.md)** (CT 104, 2 cores, 1 GB RAM).
*   Follow the **[Universal Node Bootstrap Guide](../../docs/00_Infrastructure/universal-node-bootstrap.md)** to install prerequisites and link this node to GitOps.
*   **Cron Offset:** Set the `auto_pull_repo.sh` cronjob to run at minute **32** to stagger network load.
*   **Process Logs Script:** Tracked script — cron may point at the repo path directly:
    `0 0 * * * /opt/homelab-repo/nodes/reverse-proxy/scripts/process_logs.sh`

## 2. Reverse Proxy & Security

Per-service guides cover `/srv/...` secrets, templates in the clone, and deploy/restart steps:

*   [Caddy Reverse Proxy](services/caddy/deployment.md) — `/srv/caddy/`
*   [CrowdSec IPS](services/crowdsec/deployment.md) — `/srv/crowdsec/`
*   [Fail2Ban Monitor](services/fail2ban-monitor/deployment.md) — `/srv/fail2ban-monitor/`
*   [Web-compromise watch](../../shared/observability/web-compromise-watch/deployment.md) — Caddy uid shells → Homelab Watch
*   [SSH doorbell](../../shared/observability/ssh-doorbell/deployment.md) — PAM successful SSH → Homelab Watch

## 3. Observability

*   [Gatus Status Page](services/gatus/deployment.md) — `/srv/gatus/`

## 4. Dashboard

*   [Dashy Homepage](services/dashy/deployment.md) — static build served by Caddy from `/opt/dashy/dist`
