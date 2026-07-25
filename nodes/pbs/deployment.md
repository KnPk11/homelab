# PBS-86 Master Bootstrap Guide

This node operates on a strict **Infrastructure as Intent** methodology. Do not edit tracked config directly on the server. Instead, push updates to Git, pull them on the server (`auto_pull_repo.sh`), and re-run the service deploy steps below.

**Secrets are not in Git.** Real configuration files and credentials live under `/etc/proxmox-backup/` and `/mnt/datastore/` so the clone at `/opt/homelab-repo` stays disposable. After a nuke-and-pave you must restore those from the secrets vault before services will work — a bare `git pull` is not enough.

If this machine ever suffers a catastrophic failure, follow the guides below in order.

## 1. System Bootstrap & Scripts

*   Follow the **[Universal Node Bootstrap Guide](../../shared/docs/universal-node-bootstrap.md)** to install prerequisites and link this node to GitOps.
*   **Cron Offset:** Set the `auto_pull_repo.sh` cronjob to run at minute **38** to stagger network load.

## 2. Services & Specifications

*   [Proxmox Backup Server Spec](../../docs/00_Infrastructure/Proxmox/pbs-lxc.md) — Proxmox LXC container provisioning, resource allocation, and datastore mount points.
*   [PBS Deployment & Restore Guide](../../docs/00_Infrastructure/Proxmox/proxmox-backup-server.md) — Post-install datastore configuration, WinSCP client setups, and retention models.
