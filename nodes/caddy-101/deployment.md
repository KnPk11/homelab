# Caddy-101 Master Bootstrap Guide

This node operates on a strict **Infrastructure as Intent** methodology. Do not edit tracked config directly on the server. Instead, push updates to Git, pull them on the server (`auto_pull_repo.sh`), and re-run the service deploy steps below.

**Secrets are not in Git.** Real `.env` / secret files live under `/srv/<service>/` so the clone at `/opt/homelab-repo` stays disposable. After a nuke-and-pave you must restore those from the secrets vault (or recreate from `*.env.example`) before services will work — a bare `git pull` is not enough.

If this machine ever suffers a catastrophic failure, follow the guides below in order.

## 1. System Bootstrap & Scripts

*   Follow the **[Universal Node Bootstrap Guide](../../shared/docs/universal-node-bootstrap.md)** to install prerequisites and link this node to GitOps.
*   **Cron Offset:** Set the `auto_pull_repo.sh` cronjob to run at minute **32** to stagger network load.
*   **Process Logs Script:** Tracked script — cron may point at the repo path directly:
    `0 0 * * * /opt/homelab-repo/nodes/caddy-101/scripts/process_logs.sh`

## 2. Reverse Proxy & Security

Per-service guides cover `/srv/...` secrets, templates in the clone, and deploy/restart steps:

*   [Caddy Reverse Proxy](services/Caddy/deployment.md) — `/srv/caddy/`
*   [CrowdSec IPS](services/CrowdSec/deployment.md) — `/srv/crowdsec/`
*   [Fail2Ban Monitor](services/Fail2Ban%20Monitor/deployment.md) — `/srv/fail2ban-monitor/`

## 3. Observability

*   [Gatus Status Page](services/Gatus/deployment.md) — `/srv/gatus/`
