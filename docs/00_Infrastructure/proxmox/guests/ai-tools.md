# ai-tools: Proxmox LXC Spec

> [!NOTE]
> #Proxmox #LXC #Infrastructure #AI #Automation

This document details the specific Proxmox LXC Container (CT 105) configuration for the management and AI node (`ai-tools`).

## Provisioning Details

- **Guest Type**: Proxmox LXC Container
- **CTID**: `105`
- **Template**: Debian 13 (Standard 64-bit)
- **Privileged**: No (Unprivileged container)
- **Features**: `nesting=1`

### Resource Allocation

| Setting | Value |
| :--- | :--- |
| CTID | 105 |
| Hostname | `ai-tools` |
| CPU Cores | 4 cores |
| RAM | 2048 MB (2 GB) |
| Swap | 2048 MB (2 GB) |
| Root Disk (`rootfs`) | 16 GB SSD (`local-lvm`) |
| Unprivileged | Yes (`unprivileged: 1`) |
| Nesting | Yes (`nesting=1`) |

### Network Configuration

- **IPv4/CIDR**: `192.168.50.105/24` (Static)
- **Gateway**: `192.168.50.1`
- **Bridge**: `vmbr0` (`veth`)
- **DNS Servers**: `192.168.50.102 1.1.1.1`
- **Firewall**: ✅ Enabled

## Setup Steps

1. **Create Container**: Execute via CLI on the Proxmox host:
   ```bash
   pct create 105 local:vztmpl/debian-13-standard_13.0-1_amd64.tar.zst \
     --hostname ai-tools \
     --cores 4 \
     --memory 2048 \
     --swap 2048 \
     --features nesting=1 \
     --unprivileged 1 \
     --rootfs local-lvm:16 \
     --net0 name=eth0,bridge=vmbr0,firewall=1,gw=192.168.50.1,ip=192.168.50.105/24 \
     --nameserver "192.168.50.102 1.1.1.1" \
     --ssh-public-keys /root/.ssh/authorized_keys \
     --onboot 1
   ```
2. **GitOps Runbook**: Proceed to [ai-tools Deployment Guide](../../../../nodes/ai-tools/deployment.md).
