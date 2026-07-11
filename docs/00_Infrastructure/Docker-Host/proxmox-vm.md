> [!NOTE]
> **Tags:** #Proxmox #VM #Infrastructure #Docker #Linux

# Docker Host: Proxmox VM Spec

This document details the specific Proxmox VM configuration for the primary Docker Host.

## Provisioning Details

- **Template**: Debian 13 (Standard)
- **VM Type**: qemu

### Resource Allocation

| Setting    | Value                       |
| ---------- | --------------------------- |
| OS Type    | Debian 13                   |
| CPU        | 8 cores                     |
| RAM        | 4192 MB                     |
| Disk       | 32 GB                       |

### Network Configuration

- **IPv4/CIDR**: Static IP
- **Gateway**: `192.168.1.1`
- **DNS Server**: Default
- **Firewall**: ✅ Enabled

---

## Setup Steps

1. **Create VM**: Follow the standard Proxmox VM creation wizard using the specs above.
2. **SSH Key**: Ensure your public SSH key is configured for passwordless access.
