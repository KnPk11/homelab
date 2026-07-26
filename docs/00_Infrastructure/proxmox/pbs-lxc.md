# Proxmox Backup Server: Proxmox LXC Spec

> [!NOTE]
> **Tags:** #Proxmox #PBS #LXC #Infrastructure #Backup #Storage

This document details the specific Proxmox LXC configuration for the dedicated Proxmox Backup Server (`pbs`) container node.

## Provisioning Details

- **Template**: Debian 12 (Bookworm Standard)
- **Unprivileged Container**: ✅ Yes
- **Nesting**: ✅ Yes

### Resource Allocation

| Setting | Value |
| :--- | :--- |
| OS Type | Debian 12 (Bookworm) |
| CPU | 4 cores |
| RAM | 2048 MB (2 GB) |
| Swap | 2048 MB (2 GB) |
| Root Disk | 8 GB |
| Privileged | No (unprivileged) |
| Nesting | Yes |
| Protection | Yes |
| On Boot | Yes |

### Datastore Mount Points

| Mount Point | Host Path | Container Path | Purpose |
| :--- | :--- | :--- | :--- |
| `mp0` | `/mnt/newdrive/pbs-datastore` | `/mnt/datastore/pbs` | Primary Proxmox guest backup datastore |
| `mp1` | `/mnt/newdrive/pbs-windows-datastore` | `/mnt/datastore/pbs-windows` | Windows client backup datastore |

### Network Configuration

- **IPv4/CIDR**: `[PBS-IP]/24` (Static IP: `192.168.50.86/24`)
- **Gateway**: `[GATEWAY-IP]`
- **DNS Server**: Default (Host settings)
- **Firewall**: ✅ Enabled (Managed via Proxmox)

---

## Setup Steps

1. **Create LXC Container**: Execute CLI command on Proxmox host or use Proxmox wizard:
   ```bash
   pct create 109 local:vztmpl/debian-12-standard_12.12-1_amd64.tar.zst \
     --ostype debian \
     --hostname pbs \
     --cores 4 \
     --memory 2048 \
     --swap 2048 \
     --rootfs local-lvm:8 \
     --net0 name=eth0,bridge=vmbr0,firewall=1,gw=[GATEWAY-IP],ip=[PBS-IP]/24 \
     --unprivileged 1 \
     --features nesting=1 \
     --onboot 1 \
     --protection 1
   ```

2. **Add Datastore Mount Points**:
   ```bash
   pct set 109 -mp0 /mnt/newdrive/pbs-datastore,mp=/mnt/datastore/pbs
   pct set 109 -mp1 /mnt/newdrive/pbs-windows-datastore,mp=/mnt/datastore/pbs-windows
   ```

3. **Install PBS Packages inside LXC**:
   ```bash
   pct start 109
   pct exec 109 -- apt-get update
   pct exec 109 -- apt-get install -y proxmox-backup-server
   ```

4. **Web UI Access**:
   Access the PBS web interface at `https://[PBS-IP]:8007`.

> [!TIP]
> Ensure host subuid/subgid remapping is configured so the `backup` user inside the unprivileged container can write to host mount paths.
