# dns: Proxmox LXC Spec

> [!NOTE]
> #Proxmox #LXC #Infrastructure #DNS #AdGuardHome

This document details the specific Proxmox LXC Container (CT 106) configuration for the primary network DNS server (`dns`).

## Provisioning Details

- **Guest Type**: Proxmox LXC Container
- **CTID**: `106`
- **Template**: Debian 13 (Standard 64-bit)
- **Privileged**: No (Unprivileged container)
- **Features**: `nesting=1`

### Resource Allocation

| Setting | Value |
| :--- | :--- |
| CTID | 106 |
| Hostname | `dns` |
| CPU Cores | 1 core |
| RAM | 256 MB |
| Swap | 256 MB |
| Root Disk (`rootfs`) | 8 GB SSD (`local-lvm`) |
| Unprivileged | Yes (`unprivileged: 1`) |
| Nesting | Yes (`nesting=1`) |

### Network Configuration

- **IPv4/CIDR**: `192.168.50.102/24` (Static)
- **Gateway**: `192.168.50.1`
- **Bridge**: `vmbr0` (`veth`)
- **DNS Upstreams**: `1.1.1.1 9.9.9.9`
- **Firewall**: ✅ Enabled

## Setup Steps

1. **Create Container**: Execute via CLI on the Proxmox host:
   ```bash
   pct create 106 local:vztmpl/debian-13-standard_13.0-1_amd64.tar.zst \
     --hostname dns \
     --cores 1 \
     --memory 256 \
     --swap 256 \
     --features nesting=1 \
     --unprivileged 1 \
     --rootfs local-lvm:8 \
     --net0 name=eth0,bridge=vmbr0,firewall=1,gw=192.168.50.1,ip=192.168.50.102/24 \
     --nameserver "1.1.1.1 9.9.9.9" \
     --ssh-public-keys /root/.ssh/authorized_keys \
     --onboot 1
   ```
2. **GitOps Runbook**: Proceed to [dns Deployment Guide](../../../../nodes/dns/deployment.md).
