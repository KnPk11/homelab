# MikroTik Router — Deployment Guide

> [!NOTE]
> **Tags:** #MikroTik #Router #Networking #Firewall
> **Model:** E60iUGS | **RouterOS:** 7.x | **IP:** 192.168.88.1

## 1. Overview

Because the edge router is treated as a manually configured "pet" rather than a fully declarative GitOps node, we do not export the full configuration or attempt to push it automatically. 

Instead, a scheduled script pulls a **targeted, segmented backup** of the most critical and time-consuming components (Firewall rules, NAT, Interfaces, VLANs, DHCP leases, and DNS) directly from the router into a highly readable local file.

## 2. Automated Config Capture (Cron)

A pull script runs every 3 hours on `ai-tools`, SSHes into the router, and writes a **local plaintext backup** to `nodes/ai-tools/services/mikrotik-backup/mikrotik-config-export.rsc`. This file is gitignored to prevent leaking network topology to the remote repository.

**Script:** `nodes/ai-tools/services/mikrotik-backup/capture-mikrotik-config.sh`

### One-time cron setup

```bash
crontab -e
```

Add the following line:

```
0 */3 * * * /opt/dev/homelab_repo/nodes/ai-tools/services/mikrotik-backup/capture-mikrotik-config.sh >> /var/log/capture-mikrotik-config.log 2>&1
```

### SSH key prerequisite

Cron has **no ssh-agent**, so this job must use a **passphrase-less** key. Do not point it at God Mode (`id_ed25519_ai`) or the GitHub key (`id_ed25519`) — both are encrypted and fail in BatchMode as `Permission denied (publickey)`.

On **ai-tools**:

```bash
# One-time: dedicated job key (not in Git)
ssh-keygen -t ed25519 -f ~/.ssh/id_ed25519_mt_backup -N '' -C svc_backup
```

On the router (as `svc_ai`, God Mode unlocked):

```bash
/user ssh-keys add user=svc_backup key="ssh-ed25519 AAAA... svc_backup"
```

The capture script defaults to `~/.ssh/id_ed25519_mt_backup` (`ROUTER_SSH_IDENTITY` to override).

## 3. Restoring Configs

If you make a mistake or need to rebuild a section of the router:
1. Open `nodes/ai-tools/services/mikrotik-backup/mikrotik-config-export.rsc` locally.
2. Locate the specific rule or section you need (e.g., under the `🖥️ DHCP & STATIC LEASES` header).
3. Connect to the router via WinBox or SSH and manually recreate or paste the specific `add` commands.

## 4. Files

| File | Purpose |
|------|---------|
| `nodes/ai-tools/services/mikrotik-backup/mikrotik-config-export.rsc` | Targeted component backup — **gitignored**, local backup only |
| `nodes/ai-tools/services/mikrotik-backup/capture-mikrotik-config.sh` | Automated pull script — runs via cron on `ai-tools` |
