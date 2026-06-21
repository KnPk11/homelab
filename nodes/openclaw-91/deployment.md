# OpenClaw-91 Master Bootstrap Guide

This node operates on a strict **Infrastructure as Intent** methodology. Do not edit files directly on the server. Instead, push updates to the Git repository, pull them on the server, and restart the respective services.

If this machine ever suffers a catastrophic failure, follow the deployment guides below in this exact order to nuke-and-pave it back to a working state.

## 1. System Bootstrap & Scripts
*   Follow the **[Universal Node Bootstrap Guide](../../shared/docs/universal-node-bootstrap.md)** to install prerequisites and link this node to GitOps.
*   **Cron Offset:** Set the `auto_pull_repo.sh` cronjob to run at minute **35** to stagger network load.
*   [Firewall Script](scripts/deployment.md)
