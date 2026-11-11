# ops: Proxmox LXC Spec

> [!NOTE]
> #Proxmox #LXC #Infrastructure #Ops #Automation

This document details the specific Proxmox LXC Container (CT 112) configuration for the lightweight operations and background automation plane (`ops`).

## Provisioning Details

- **Guest Type**: Proxmox LXC Container
- **CTID**: `112`
- **Template**: Debian 13 (Standard 64-bit)
- **Privileged**: No (Unprivileged container)
- **Features**: `nesting=1`

### Resource Allocation

| Setting | Value |
| :--- | :--- |
| CTID | 112 |
| Hostname | `ops` |
| CPU Cores | 1 core |
| RAM | 512 MB |
| Swap | 512 MB |
| Root Disk (`rootfs`) | 4 GB SSD (`local-lvm`) |
| Unprivileged | Yes (`unprivileged: 1`) |
| Nesting | Yes (`nesting=1`) |

### Network Configuration

- **IPv4/CIDR**: `192.168.50.112/24` (Static)
- **Gateway**: `192.168.50.1`
- **Bridge**: `vmbr0` (`veth`)
- **DNS Servers**: `192.168.50.102 1.1.1.1`
- **Firewall**: ✅ Enabled

## Setup Steps

1. **Create Container**: Execute via CLI on the Proxmox host:
   ```bash
   pct create 112 local:vztmpl/debian-13-standard_13.0-1_amd64.tar.zst \
     --hostname ops \
     --cores 1 \
     --memory 512 \
     --swap 512 \
     --features nesting=1 \
     --unprivileged 1 \
     --rootfs local-lvm:4 \
     --net0 name=eth0,bridge=vmbr0,firewall=1,gw=192.168.50.1,ip=192.168.50.112/24 \
     --nameserver "192.168.50.102 1.1.1.1" \
     --onboot 1
   ```
2. **GitOps Runbook**: Proceed to [ops Deployment Guide](../../../../nodes/ops/deployment.md).
