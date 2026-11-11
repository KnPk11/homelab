# reverse-proxy: Proxmox LXC Spec

> [!NOTE]
> #Proxmox #LXC #Infrastructure #ReverseProxy #Caddy

This document details the specific Proxmox LXC Container (CT 104) configuration for the ingress reverse proxy (`reverse-proxy`).

## Provisioning Details

- **Guest Type**: Proxmox LXC Container
- **CTID**: `104`
- **Template**: Debian 13 (Standard 64-bit)
- **Privileged**: No (Unprivileged container)
- **Features**: `nesting=1`

### Resource Allocation

| Setting | Value |
| :--- | :--- |
| CTID | 104 |
| Hostname | `reverse-proxy` |
| CPU Cores | 2 cores |
| RAM | 1024 MB (1 GB) |
| Swap | 1024 MB (1 GB) |
| Root Disk (`rootfs`) | 16 GB SSD (`local-lvm`) |
| Mount Point (`mp0`) | 10 GB SSD (`local-lvm:vm-104-disk-1`, mounted at `/mnt/logs`) |
| Unprivileged | Yes (`unprivileged: 1`) |
| Nesting | Yes (`nesting=1`) |

### Network Configuration

- **IPv4/CIDR**: `192.168.50.101/24` (Static)
- **Gateway**: `192.168.50.1`
- **Bridge**: `vmbr0` (`veth`)
- **DNS Servers**: `192.168.50.102 1.1.1.1`
- **Firewall**: ✅ Enabled

## Setup Steps

1. **Create Container**: Execute via CLI on the Proxmox host:
   ```bash
   pct create 104 local:vztmpl/debian-13-standard_13.0-1_amd64.tar.zst \
     --hostname reverse-proxy \
     --cores 2 \
     --memory 1024 \
     --swap 1024 \
     --features nesting=1 \
     --unprivileged 1 \
     --rootfs local-lvm:16 \
     --net0 name=eth0,bridge=vmbr0,firewall=1,gw=192.168.50.1,ip=192.168.50.101/24 \
     --nameserver "192.168.50.102 1.1.1.1" \
     --onboot 1
   ```
2. **Attach Log Mountpoint**:
   ```bash
   pct set 104 -mp0 local-lvm:10,mp=/mnt/logs
   ```
3. **GitOps Runbook**: Proceed to [reverse-proxy Deployment Guide](../../../../nodes/reverse-proxy/deployment.md).
