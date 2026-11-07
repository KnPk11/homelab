# MikroTik Router — Deployment Guide

> [!NOTE]
> **Tags:** #MikroTik #Router #Networking #Firewall
> **Model:** E60iUGS | **RouterOS:** 7.x | **IP:** 192.168.88.1

## 1. Overview

Because the edge router is treated as a manually configured "pet" rather than a fully declarative GitOps node, we do not export the full configuration or attempt to push it automatically. 

Instead, a scheduled script pulls a **targeted, segmented backup** of the most critical and time-consuming components (Firewall rules, NAT, Interfaces, VLANs, DHCP leases, and DNS) directly from the router into a highly readable local file.

## 2. Automated Config Capture (Cron & Gitea)

A pull script runs every 3 hours on **ops** (CT 112), connects to the router via SSH, and commits changes directly into a private self-hosted Gitea repository (`https://gitea.[DOMAIN]/kp/mikrotik-config`). If no changes are detected between runs, no commits are produced. Backups are also mirrored to `/srv/mikrotik-backup/backups/`.

**Script:** `nodes/ops/services/mikrotik-backup/capture-mikrotik-config.sh`
**Git Repository:** `/srv/mikrotik-config` (upstream: `https://gitea.[DOMAIN]/kp/mikrotik-config.git`)

### One-time cron setup

```bash
crontab -e
```

Add the following line:

```
0 */3 * * * /opt/homelab-repo/nodes/ops/services/mikrotik-backup/capture-mikrotik-config.sh >> /var/log/capture-mikrotik-config.log 2>&1
```

### SSH key prerequisite

Cron has **no ssh-agent**, so this job must use a **passphrase-less** key. Do not point it at God Mode (`id_ed25519_ai`) or the GitHub key (`id_ed25519`) — both are encrypted and fail in BatchMode as `Permission denied (publickey)`.

The dedicated job key lives at `/root/.ssh/id_ed25519_mt_backup` on **ops** (copied from `ai-tools`).
Firewall rule on MikroTik accepts incoming SSH on port 22 from `192.168.50.112`.

On the router (as `svc_ai`, God Mode unlocked):

```bash
/user ssh-keys add user=svc_backup key="ssh-ed25519 AAAA... svc_backup"
```

The capture script defaults to `~/.ssh/id_ed25519_mt_backup` (`ROUTER_SSH_IDENTITY` to override).

## 3. Auditing & Restoring Configs

* **Visual Diffs & History:** Browse `https://gitea.[DOMAIN]/kp/mikrotik-config` to view every configuration change, side-by-side diff, and commit log with original timestamps.
* **Monthly Audit Integration:** `monthly-audit.sh` on **ai-tools** automatically pulls from Gitea and extracts the latest RouterOS commit diff into the audit digest.
* **Restoring:**
  1. Open `mikrotik-config.rsc` from Gitea or `/opt/dev/secrets_vault/mikrotik-config/`.
  2. Locate the specific section you need (e.g., under the `🖥️ DHCP & STATIC LEASES` header).
  3. Connect to the router via WinBox or SSH and paste or apply the commands.

## 4. Files

| File | Purpose |
|------|---------|
| `https://gitea.[DOMAIN]/kp/mikrotik-config.git` | Primary private GitOps backup repository in self-hosted Gitea |
| `/srv/mikrotik-config/` | Working clone on **ops** (CT 112) |
| `/opt/dev/secrets_vault/mikrotik-config/` | Working clone on **ai-tools** (CT 105) for local VS Code & offline vault sweeps |
| `nodes/ops/services/mikrotik-backup/capture-mikrotik-config.sh` | Automated pull script — runs via cron on **ops** |
