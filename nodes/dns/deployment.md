# dns: Master Bootstrap Guide

> **Hostname:** `dns` | **IP:** `192.168.50.102` | **Proxmox:** CT 106 | **Type:** Proxmox LXC (AdGuard Home)

This node operates on a strict **Infrastructure as Intent** methodology. Do not edit tracked config directly on the server. Instead, push updates to Git, synchronise the node from `ai-tools` (`sync-nodes <node>`), and re-run the service deploy steps below.

**Secrets are not in Git.** Real env files live under `/srv/<service>/` so the clone at `/opt/homelab-repo` stays disposable. After a nuke-and-pave you must restore those from the secrets vault (or recreate from `*.env.example`) before services will work — a bare `git pull` is not enough.

If this machine ever suffers a catastrophic failure, follow the guides below in order.

## 1. System Bootstrap

*   **Proxmox LXC Spec:** Review container allocation in **[Proxmox LXC Spec](../../docs/00_Infrastructure/proxmox/guests/dns.md)** (CT 106, 1 core, 256 MB RAM).
*   Follow the **[Universal Node Bootstrap Guide](../../docs/00_Infrastructure/universal-node-bootstrap.md)** to install prerequisites and link this node to GitOps.

## 2. DNS Services

*   [AdGuardHome](services/adguard/deployment.md) — `/srv/adguard/`
