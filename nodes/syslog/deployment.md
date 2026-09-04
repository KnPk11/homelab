# Syslog-89 Master Bootstrap Guide

This node operates on a strict **Infrastructure as Intent** methodology. Do not edit tracked config directly on the server. Instead, push updates to Git, pull them on the server (`auto_pull_repo.sh`), and re-run the service deploy steps below.

**Secrets are not in Git.** Homelab Watch env lives under `/srv/homelab-watch/` (and `/etc/ssh/telegram.env`) so the clone at `/opt/homelab-repo` stays disposable. After a nuke-and-pave you must restore those from the secrets vault before `auth-watch` will Telegram — a bare `git pull` is not enough.

If this machine ever suffers a catastrophic failure, follow the guides below in order.

## 1. System Bootstrap & Scripts

*   Follow the **[Universal Node Bootstrap Guide](../../shared/docs/universal-node-bootstrap.md)** to install prerequisites and link this node to GitOps.
*   **Cron Offset:** Set the `auto_pull_repo.sh` cronjob to run at minute **41** to stagger network load.
*   **LXC spec:** [Syslog Proxmox LXC](../../docs/02_Services/syslog/proxmox-lxc.md) — VMID, disk, IP, firewall groups.

## 2. Off-box auth

*   [Auth store](services/auth-store/deployment.md) — rsyslog `:514` → `/mnt/logs/auth/<host>/auth.log`, `auth-logs`, silent-host watch
*   [Auth-ship](../../shared/observability/auth-ship/deployment.md) — per-node forwarder (not installed on this CT)
*   [SMB `logs` share](services/smb/deployment.md) — Windows backup of `/mnt/logs`, same `loguser` as reverse-proxy
*   [SSH doorbell](../../shared/observability/ssh-doorbell/deployment.md) — PAM successful SSH → Homelab Watch
