# Caddy-101 Master Bootstrap Guide

This node operates on a strict **Infrastructure as Intent** methodology. Do not edit files directly on the server. Instead, push updates to the Git repository, pull them on the server, and restart the respective services.

If this machine ever suffers a catastrophic failure, follow the deployment guides below in this exact order to nuke-and-pave it back to a working state.

## 1. System Bootstrap & Scripts
*   Follow the **[Universal Node Bootstrap Guide](../../shared/docs/universal-node-bootstrap.md)** to install prerequisites and link this node to GitOps.
*   **Cron Offset:** Set the `auto_pull_repo.sh` cronjob to run at minute **32** to stagger network load.
*   **Process Logs Script:** The log rotation script runs daily at midnight via the root user's `crontab`. Add the following entry:
    `0 0 * * * /opt/homelab-repo/nodes/caddy-101/scripts/process_logs.sh`

## 2. Reverse Proxy & Security
*   [Caddy Reverse Proxy](services/Caddy/deployment.md)
*   [CrowdSec IPS](services/CrowdSec/deployment.md)
*   [Fail2Ban Monitor](services/Fail2Ban\ Monitor/deployment.md)

## 3. Observability
*   [Gatus Status Page](services/Gatus/deployment.md)
