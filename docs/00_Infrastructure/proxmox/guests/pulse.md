# pulse: Proxmox LXC Spec

> [!NOTE]
> #Proxmox #LXC #Infrastructure #Pulse #Monitoring

This document details the specific Proxmox LXC Container (CT 107) configuration for the Pulse monitoring daemon (`pulse`).

## Provisioning Details

- **Guest Type**: Proxmox LXC Container
- **CTID**: `107`
- **Template**: Debian 13 (Standard 64-bit)
- **Privileged**: No (Unprivileged container)
- **Features**: `nesting=1`

### Resource Allocation

| Setting | Value |
| :--- | :--- |
| CTID | 107 |
| Hostname | `pulse` |
| CPU Cores | 2 cores |
| RAM | 1024 MB (1 GB) |
| Swap | 512 MB |
| Root Disk (`rootfs`) | 8 GB SSD (`local-lvm`) |
| Unprivileged | Yes (`unprivileged: 1`) |
| Nesting | Yes (`nesting=1`) |

### Network Configuration

- **IPv4/CIDR**: `192.168.50.88/24` (Static)
- **Gateway**: `192.168.50.1`
- **Bridge**: `vmbr0` (`veth`)
- **Firewall**: ✅ Enabled

## Setup Steps

1. **Create Container**: Execute via CLI on the Proxmox host:
   ```bash
   pct create 107 local:vztmpl/debian-13-standard_13.0-1_amd64.tar.zst \
     --hostname pulse \
     --cores 2 \
     --memory 1024 \
     --swap 512 \
     --features nesting=1 \
     --unprivileged 1 \
     --rootfs local-lvm:8 \
     --net0 name=eth0,bridge=vmbr0,firewall=1,gw=192.168.50.1,ip=192.168.50.88/24 \
     --onboot 1
   ```
2. **GitOps Runbook**: Proceed to [pulse Deployment Guide](../../../../nodes/pulse/deployment.md).
