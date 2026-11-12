# syslog: Master Bootstrap Guide

> **Hostname:** `syslog` | **IP:** `192.168.50.89` | **Proxmox:** CT 111 | **Type:** Proxmox LXC (Auth Store & Syslog)

This node operates on a strict **Infrastructure as Intent** methodology. Do not edit tracked config directly on the server. Instead, push updates to Git, synchronise the node from `ai-tools` (`sync-nodes <node>`), and re-run the service deploy steps below.

**Secrets are not in Git.** Homelab Watch env lives under `/srv/homelab-watch/` (and `/etc/ssh/telegram.env`) so the clone at `/opt/homelab-repo` stays disposable. After a nuke-and-pave you must restore those from the secrets vault before `auth-watch` will Telegram — a bare `git pull` is not enough.

If this machine ever suffers a catastrophic failure, follow the guides below in order.

## 1. System Bootstrap & Scripts

*   Follow the **[Universal Node Bootstrap Guide](../../docs/00_Infrastructure/universal-node-bootstrap.md)** to install prerequisites and link this node to GitOps.
*   **LXC spec:** [Syslog Proxmox LXC](../../docs/00_Infrastructure/proxmox/guests/syslog.md) — VMID, disk, IP, firewall groups.

## 2. Off-box auth

*   [Auth store](services/auth-store/deployment.md) — rsyslog `:514` → `/mnt/logs/auth/<host>/auth.log`, `auth-logs`, silent-host watch
*   [Auth-ship](../../shared/observability/auth-ship/deployment.md) — per-node forwarder (not installed on this CT)
*   [SMB `logs` share](services/smb/deployment.md) — Windows backup of `/mnt/logs`, same `loguser` as reverse-proxy
*   [SSH doorbell](../../shared/observability/ssh-doorbell/deployment.md) — PAM successful SSH → Homelab Watch
