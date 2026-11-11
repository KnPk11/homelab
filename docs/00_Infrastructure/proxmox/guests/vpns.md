# vpns: Proxmox LXC Spec

> [!NOTE]
> #Proxmox #LXC #Infrastructure #WireGuard #Tailscale #VPN #Networking

This document details the specific Proxmox LXC Container (CT 108) configuration for the dedicated VPN gateway container (`vpns`), hosting Tailscale and WireGuard subnet routers.

## Provisioning Details

- **Guest Type**: Proxmox LXC Container
- **CTID**: `108`
- **Template**: Debian 13 (Standard 64-bit)
- **Privileged**: No (Unprivileged container)
- **Features**: `nesting=1, keyctl=1`
- **Device Passthrough**: `/dev/net/tun`

### Resource Allocation

| Setting | Value |
| :--- | :--- |
| CTID | 108 |
| Hostname | `vpns` |
| CPU Cores | 1 core |
| RAM | 1024 MB (1 GB) |
| Swap | 1024 MB (1 GB) |
| Root Disk (`rootfs`) | 8 GB SSD (`local-lvm`) |
| Unprivileged | Yes (`unprivileged: 1`) |
| Nesting / Keyctl | Yes (`nesting=1,keyctl=1`) |

### Network Configuration

- **IPv4/CIDR**: `192.168.50.87/24` (Static DHCP Reservation)
- **Gateway**: `192.168.50.1`
- **Bridge**: `vmbr0` (`veth`)
- **Firewall**: ✅ Enabled

## Setup Steps

1. **Create Container**: Execute via CLI on the Proxmox host:
   ```bash
   pct create 108 local:vztmpl/debian-13-standard_13.0-1_amd64.tar.zst \
     --hostname vpns \
     --cores 1 \
     --memory 1024 \
     --swap 1024 \
     --features nesting=1,keyctl=1 \
     --unprivileged 1 \
     --rootfs local-lvm:8 \
     --net0 name=eth0,bridge=vmbr0,firewall=1,ip=dhcp \
     --ssh-public-keys /root/.ssh/authorized_keys \
     --onboot 1
   ```
2. **Configure TUN Device Passthrough**:
   Append the following lines to `/etc/pve/lxc/108.conf` on the Proxmox host:
   ```text
   lxc.cgroup2.devices.allow: c 10:200 rwm
   lxc.mount.entry: /dev/net/tun dev/net/tun none bind,create=file
   ```
3. **GitOps Runbook**: Proceed to [vpns Deployment Guide](../../../../nodes/vpns/deployment.md).
