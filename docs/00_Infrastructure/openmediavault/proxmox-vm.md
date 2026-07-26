> [!NOTE]
> **Tags:** #Proxmox #VM #Infrastructure #OMV #Storage

# OpenMediaVault: Proxmox VM Spec

This document details the specific Proxmox VM configuration for OpenMediaVault.

## Provisioning Details

- **Template**: Debian 13 (Standard)
- **VM Type**: qemu

### Resource Allocation

| Setting    | Value                       |
| ---------- | --------------------------- |
| OS Type    | Debian 13                   |
| CPU        | 2 cores                     |
| RAM        | 2048 MB (8GB+ for ZFS)      |
| Disk       | 16 GB                       |

### Network Configuration

- **IPv4/CIDR**: Static IP
- **Gateway**: `192.168.1.1`
- **DNS Server**: Default
- **Firewall**: ✅ Enabled

---

## Setup Steps

1. **Create VM**: Follow the standard Proxmox VM creation wizard using the specs above.
2. **Add Storage Drive**: OMV requires a second drive to actually store your data. After creation, add a large virtual disk (e.g., 2TB) or passthrough a physical hard drive to the VM.
3. **SSH Key**: Ensure your public SSH key is configured.
