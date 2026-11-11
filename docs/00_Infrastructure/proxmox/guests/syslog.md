# syslog: Proxmox LXC Spec

> [!NOTE]
> #Proxmox #LXC #Infrastructure #Syslog #Rsyslog #Logging

This document details the specific Proxmox LXC Container (CT 111) configuration for the centralised off-box auth log collector (`syslog`).

## Provisioning Details

- **Guest Type**: Proxmox LXC Container
- **CTID**: `111`
- **Template**: Debian 13 (Standard 64-bit)
- **Privileged**: No (Unprivileged container)
- **Features**: `nesting=1`

### Resource Allocation

| Setting | Value |
| :--- | :--- |
| CTID | 111 |
| Hostname | `syslog` |
| CPU Cores | 1 core |
| RAM | 1024 MB (1 GB) |
| Swap | 512 MB |
| Root Disk (`rootfs`) | 8 GB SSD (`local-lvm`) |
| Log Volume (`mp0`) | 4 GB SSD (`local-lvm:vm-111-disk-1`, mounted at `/mnt/logs`) |
| Unprivileged | Yes (`unprivileged: 1`) |
| Nesting | Yes (`nesting=1`) |

### Network Configuration

- **IPv4/CIDR**: `192.168.50.89/24` (Static)
- **Gateway**: `192.168.50.1`
- **Bridge**: `vmbr0` (`veth`)
- **DNS Server**: `192.168.50.102`
- **Firewall**: ✅ Enabled

## Setup Steps

1. **Create Container**: Execute via CLI on the Proxmox host:
   ```bash
   pct create 111 local:vztmpl/debian-13-standard_13.0-1_amd64.tar.zst \
     --hostname syslog \
     --cores 1 \
     --memory 1024 \
     --swap 512 \
     --features nesting=1 \
     --unprivileged 1 \
     --rootfs local-lvm:8 \
     --net0 name=eth0,bridge=vmbr0,firewall=1,gw=192.168.50.1,ip=192.168.50.89/24 \
     --nameserver 192.168.50.102 \
     --onboot 1
   ```
2. **Attach Log Mountpoint**:
   ```bash
   pct set 111 -mp0 local-lvm:4,mp=/mnt/logs
   ```
3. **GitOps Runbook**: Proceed to [syslog Deployment Guide](../../../../nodes/syslog/deployment.md).
