# Syslog: Proxmox LXC Spec

> [!NOTE]
> #Proxmox #LXC #Infrastructure #Syslog #Rsyslog

This document details the specific Proxmox LXC configuration for the off-box auth log collector. Node bootstrap: [syslog deployment.md](../../../nodes/syslog/deployment.md).

## Provisioning Details

- **Template**: Debian 13 (Standard)
- **Unprivileged Container**: ✅ Yes
- **Nesting**: ✅ Yes (systemd 257)

### Resource Allocation

| Setting | Value |
| :--- | :--- |
| OS Type | Debian 13 |
| CPU | 1 core |
| RAM | 1024 MiB |
| Rootfs | `local-lvm:8` |
| Log disk | `local-lvm:4` → `mp0` → `/mnt/logs` |
| Privileged | No (unprivileged) |
| Nesting | Yes |
| On Boot | Yes |

Same extra-disk idea as reverse-proxy `/mnt/logs` (10G Caddy/MikroTik). Auth is much smaller — 4G, **~1 year** of rotated `auth.log` files (`maxage 400`). Grow `mp0` later if the disk ever fills.

### Network Configuration

- **IPv4/CIDR**: `192.168.50.89/24` (static; not a DHCP client)
- **Gateway**: `192.168.50.1`
- **Firewall**: guest `111.fw` — `ssh-adm`, `ping-trusted`, `auth-log-svc` (TCP 514), `file-svc`. No `web-pub`.

This IP needs the same MikroTik LAN NAT/forward treatment as other `.50.x` LXCs (apt/Telegram from the CT).

### Backup

PBS datastore **`pbs-linux`**, VMID **111**.
