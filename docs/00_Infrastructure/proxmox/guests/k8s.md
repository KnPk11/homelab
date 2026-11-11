# k8s: Proxmox LXC Spec

> [!NOTE]
> #Proxmox #LXC #Infrastructure #Kubernetes #k3s #Containers

This document details the specific Proxmox LXC Container (CT 110) configuration for the lightweight single-node k3s Kubernetes cluster (`k8s`).

## Provisioning Details

- **Guest Type**: Proxmox LXC Container
- **CTID**: `110`
- **Template**: Debian 13 (Standard 64-bit)
- **Privileged**: No (Unprivileged with nested k3s capabilities)
- **Features**: `nesting=1, keyctl=1`
- **Special LXC Flags**: AppArmor unconfined, kmsg passthrough

### Resource Allocation

| Setting | Value |
| :--- | :--- |
| CTID | 110 |
| Hostname | `k8s` |
| CPU Cores | 2 cores |
| RAM | 2048 MB (2 GB) |
| Swap | 2048 MB (2 GB) |
| Root Disk (`rootfs`) | 16 GB SSD (`local-lvm`) |
| Unprivileged | Yes (`unprivileged: 1`) |
| Nesting / Keyctl | Yes (`nesting=1,keyctl=1`) |

### Network Configuration

- **IPv4/CIDR**: `192.168.50.96/24` (Static)
- **Gateway**: `192.168.50.1`
- **Bridge**: `vmbr0` (`veth`)
- **DNS Server**: `192.168.50.102`
- **Firewall**: ✅ Enabled

## Setup Steps

1. **Create Container**: Execute via CLI on the Proxmox host:
   ```bash
   pct create 110 local:vztmpl/debian-13-standard_13.0-1_amd64.tar.zst \
     --hostname k8s \
     --cores 2 \
     --memory 2048 \
     --swap 2048 \
     --features nesting=1,keyctl=1 \
     --unprivileged 1 \
     --rootfs local-lvm:16 \
     --net0 name=eth0,bridge=vmbr0,firewall=1,gw=192.168.50.1,ip=192.168.50.96/24 \
     --nameserver 192.168.50.102 \
     --onboot 1
   ```
2. **Configure k3s Container Nesting**:
   Append the following required cgroup and security exemptions to `/etc/pve/lxc/110.conf` on the Proxmox host:
   ```text
   lxc.apparmor.profile: unconfined
   lxc.cap.drop:
   lxc.cgroup2.devices.allow: a
   lxc.mount.auto: proc:rw sys:rw
   lxc.mount.entry: /dev/kmsg dev/kmsg none bind,optional,create=file
   lxc.cgroup2.devices.allow: c 1:11 rwm
   ```
3. **GitOps Runbook**: Proceed to [k8s Deployment Guide](../../../../nodes/k8s/deployment.md).
