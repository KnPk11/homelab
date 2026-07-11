> [!NOTE]
> **Tags:** #Proxmox #LXC #Infrastructure #AI

# AI Node: Proxmox LXC Spec

This document details the specific Proxmox LXC configuration for the AI Node.

## Provisioning Details

- **Template**: Debian 13 (Standard)
- **Unprivileged Container**: ✅ Yes
- **Nesting**: ✅ Yes

### Resource Allocation

| Setting    | Value                       |
| ---------- | --------------------------- |
| OS Type    | Debian 13                   |
| CPU        | 2 cores                     |
| RAM        | 2048 MB                     |
| Swap       | 2048 MB                     |
| Disk       | 12 GB                       |
| Privileged | No (unprivileged preferred) |
| Nesting    | Yes                         |

### Network Configuration

- **IPv4/CIDR**: Static IP
- **Gateway**: `192.168.1.1`
- **DNS Server**: Default
- **Firewall**: ✅ Enabled

---

## Setup Steps

1. **Create LXC**: Follow the standard Proxmox LXC creation wizard using the specs above.
2. **SSH Key**: Paste your public SSH key `[SECRET]` during creation.
3. **ACLs**: Default.
