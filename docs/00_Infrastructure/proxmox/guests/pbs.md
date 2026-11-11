# pbs: Proxmox LXC Spec

> [!NOTE]
> #Proxmox #PBS #LXC #Infrastructure #Backup #Storage

This document details the specific Proxmox LXC Container (CT 109) configuration for the dedicated Proxmox Backup Server (`pbs`) container node.

## Provisioning Details

- **Guest Type**: Proxmox LXC Container
- **CTID**: `109`
- **Template**: Debian 12 (Bookworm Standard)
- **Privileged**: No (Unprivileged container)
- **Features**: `nesting=1`

### Resource Allocation

| Setting | Value |
| :--- | :--- |
| CTID | 109 |
| Hostname | `pbs` |
| CPU Cores | 4 cores |
| RAM | 2048 MB (2 GB) |
| Swap | 2048 MB (2 GB) |
| Root Disk (`rootfs`) | 8 GB SSD (`local-lvm`) |
| Mount Point 0 (`mp0`) | `/mnt/newdrive/pbs-datastore` → `/mnt/datastore/pbs` |
| Mount Point 1 (`mp1`) | `/mnt/newdrive/pbs-windows-datastore` → `/mnt/datastore/pbs-windows` |
| Unprivileged | Yes (`unprivileged: 1`) |
| Nesting | Yes (`nesting=1`) |

### Network Configuration

- **IPv4/CIDR**: `192.168.50.86/24` (Static)
- **Gateway**: `192.168.50.1`
- **Bridge**: `vmbr0` (`veth`)
- **Firewall**: ✅ Enabled

## Setup Steps

1. **Create Container**: Execute via CLI on the Proxmox host:
   ```bash
   pct create 109 local:vztmpl/debian-12-standard_12.7-1_amd64.tar.zst \
     --hostname pbs \
     --cores 4 \
     --memory 2048 \
     --swap 2048 \
     --features nesting=1 \
     --unprivileged 1 \
     --rootfs local-lvm:8 \
     --net0 name=eth0,bridge=vmbr0,firewall=1,gw=192.168.50.1,ip=192.168.50.86/24 \
     --ssh-public-keys /root/.ssh/authorized_keys \
     --onboot 1
   ```
2. **Attach Storage Mountpoints**:
   ```bash
   pct set 109 -mp0 /mnt/newdrive/pbs-datastore,mp=/mnt/datastore/pbs
   pct set 109 -mp1 /mnt/newdrive/pbs-windows-datastore,mp=/mnt/datastore/pbs-windows
   ```
3. **Install PBS Packages**: Inside CT 109, add the Proxmox Backup Server repository and install `proxmox-backup-server`.
4. **GitOps Runbook**: Proceed to [pbs Deployment Guide](../../../../nodes/pbs/deployment.md).
