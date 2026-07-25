# VPNs: Proxmox LXC Spec

> [!NOTE]
> **Tags:** #Proxmox #LXC #Infrastructure #WireGuard #Tailscale #VPN #Networking

This document details the specific Proxmox LXC configuration for the dedicated VPN gateway container (`vpns`), hosting Tailscale and WireGuard subnet routing.

## Provisioning Details

- **Template**: Debian 13 (Standard)
- **Unprivileged Container**: ✅ Yes
- **Nesting**: ✅ Yes
- **Keyctl**: ✅ Yes
- **TUN Device Passthrough**: ✅ Required (`/dev/net/tun`)

### Resource Allocation

| Setting | Value |
| :--- | :--- |
| OS Type | Debian 13 |
| CPU | 1 core (CPULimit: 1) |
| RAM | 1024 MB (1 GB) |
| Swap | 1024 MB (1 GB) |
| Disk | 8 GB |
| Privileged | No (unprivileged) |
| Nesting | Yes |
| Keyctl | Yes |
| Protection | Yes |
| On Boot | Yes (Startup order: 20) |

### Network Configuration

- **IPv4/CIDR**: `[VPNS-IP]/24` (Static IP / DHCP Reservation)
- **Gateway**: `[GATEWAY-IP]`
- **DNS Server**: Default (Host settings)
- **Firewall**: ✅ Enabled (Managed via Proxmox)

---

## Setup Steps

1. **Create LXC**: Create the container shell via Proxmox UI or host CLI:
   ```bash
   pct create 108 local:vztmpl/debian-13-standard_13.0-1_amd64.tar.zst \
     --ostype debian \
     --hostname vpns \
     --cores 1 \
     --cpulimit 1 \
     --memory 1024 \
     --swap 1024 \
     --rootfs local-lvm:8 \
     --net0 name=eth0,bridge=vmbr0,firewall=1,ip=dhcp \
     --unprivileged 1 \
     --features nesting=1,keyctl=1 \
     --onboot 1 \
     --startup order=20 \
     --protection 1
   ```

2. **Configure TUN Device Passthrough**:
   To allow Tailscale / WireGuard to establish tunnel interfaces inside an unprivileged LXC, append the following device cgroup rules to `/etc/pve/lxc/108.conf` on the Proxmox host:
   ```ini
   lxc.cgroup2.devices.allow: c 10:200 rwm
   lxc.mount.entry: /dev/net/tun dev/net/tun none bind,create=file
   ```

3. **Start Container & Bootstrap**:
   ```bash
   pct start 108
   ```

> [!IMPORTANT]
> Without the `/dev/net/tun` bind mount entries in `/etc/pve/lxc/108.conf`, WireGuard and Tailscale will fail to create virtual network interfaces inside the unprivileged container.
