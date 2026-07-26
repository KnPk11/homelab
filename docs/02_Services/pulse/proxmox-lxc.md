# Pulse: Proxmox LXC Spec

> [!NOTE]
> **Tags:** #Proxmox #LXC #Infrastructure #Pulse #Monitoring

This document details the specific Proxmox LXC configuration for the Pulse multi-host monitoring service.

## Provisioning Details

- **Template**: Debian 13 (Standard)
- **Unprivileged Container**: ✅ Yes
- **Nesting**: ✅ Yes

### Resource Allocation

| Setting | Value |
| :--- | :--- |
| OS Type | Debian 13 |
| CPU | 2 cores |
| RAM | 1024 MB (1 GB) |
| Swap | 512 MB |
| Disk | 6 GB |
| Privileged | No (unprivileged) |
| Nesting | Yes |
| Keyctl | No |
| Protection | Yes |
| On Boot | Yes |

### Network Configuration

- **IPv4/CIDR**: `[PULSE-IP]/24` (Static reservation recommended)
- **Gateway**: `[GATEWAY-IP]`
- **DNS Server**: Default (Host settings)
- **Firewall**: ✅ Enabled (Managed via Proxmox)

---

## Setup Steps

1. **Create LXC**: Follow the standard Proxmox LXC creation wizard using the specs above, or execute via CLI on the Proxmox host:
   ```bash
   pct create 107 local:vztmpl/debian-13-standard_13.0-1_amd64.tar.zst \
     --ostype debian \
     --hostname pulse \
     --cores 2 \
     --memory 1024 \
     --swap 512 \
     --rootfs local-lvm:6 \
     --net0 name=eth0,bridge=vmbr0,firewall=1,gw=[GATEWAY-IP],ip=[PULSE-IP]/24 \
     --unprivileged 1 \
     --features nesting=1 \
     --onboot 1 \
     --protection 1
   ```
2. **SSH Key**: Paste your public SSH key `[SECRET]` during creation for passwordless access.
3. **Prerequisites**: Ensure `rsync` is installed inside the LXC after creation to support on-demand secrets scraping:
   ```bash
   pct exec 107 -- apt-get update && pct exec 107 -- apt-get install -y rsync
   ```

> [!TIP]
> Pulse benefits from container protection (`--protection 1`) to prevent accidental destruction or shutdown from the Proxmox UI without unlocking first.
