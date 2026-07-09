# MikroTik Router — Deployment Guide

> [!NOTE]
> **Tags:** #MikroTik #Router #Networking #Firewall
> **Model:** E60iUGS | **RouterOS:** 7.x | **IP:** 192.168.88.1

## 1. Overview

Because the edge router is treated as a manually configured "pet" rather than a fully declarative GitOps node, we do not export the full configuration or attempt to push it automatically. 

Instead, a scheduled script pulls a **targeted, segmented backup** of the most critical and time-consuming components (Firewall rules, NAT, Interfaces, VLANs, DHCP leases, and DNS) directly from the router into a highly readable local file.

## 2. Automated Config Capture (Cron)

A pull script runs every 3 hours on `ai-tools-105`, SSHes into the router, and writes a **local plaintext backup** to `nodes/mikrotik-router/mikrotik-config-export.rsc`. This file is gitignored to prevent leaking network topology to the remote repository.

**Script:** `nodes/mikrotik-router/capture-mikrotik-config.sh`

### One-time cron setup

```bash
crontab -e
```

Add the following line:

```
0 */3 * * * /opt/dev/homelab_repo/nodes/mikrotik-router/capture-mikrotik-config.sh >> /var/log/capture-mikrotik-config.log 2>&1
```

### SSH key prerequisite

The script uses key-based auth (`gemini@192.168.88.1`). Ensure the executing user's public key is authorised on the router:

```bash
# Copy public key to the router
ssh-copy-id -i ~/.ssh/id_ed25519.pub gemini@192.168.88.1
```

## 3. Restoring Configs

If you make a mistake or need to rebuild a section of the router:
1. Open `mikrotik-config-export.rsc` locally.
2. Locate the specific rule or section you need (e.g., under the `🖥️ DHCP & STATIC LEASES` header).
3. Connect to the router via WinBox or SSH and manually recreate or paste the specific `add` commands.

## 4. Files

| File | Purpose |
|------|---------|
| `mikrotik-config-export.rsc` | Targeted component backup — **gitignored**, local backup only |
| `capture-mikrotik-config.sh` | Automated pull script — runs via cron on `ai-tools-105` |
