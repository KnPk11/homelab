> [!NOTE]
> **Tags:** #Proxmox #LXC #Infrastructure #AdGuardHome #Networking

# AdGuard Home: Proxmox LXC Spec

This document details the specific Proxmox LXC configuration for the AdGuard Home service.

## Provisioning Details

- **Template**: Debian 13 (Standard)
- **Unprivileged Container**: ✅ Yes
- **Nesting**: ✅ Yes

### Resource Allocation

| Resource | Value |
| :--- | :--- |
| **CPU Cores** | 1 |
| **Memory (RAM)** | 512 MiB |
| **Disk Size** | 8 GiB |

### Network Configuration

- **IPv4/CIDR**: `192.168.1.102/24` (Static)
- **Gateway**: `192.168.1.1`
- **DNS Server**: `9.9.9.9` (Initial setup)
- **Firewall**: ✅ Enabled (Managed via Proxmox)

---

## Setup Steps

1. **Create LXC**: Follow the standard Proxmox LXC creation wizard using the specs above.
2. **SSH Key**: Paste your public SSH key `[SECRET]` during creation for passwordless access.
3. **ACLs**: Leave as **Default** to ensure standard Linux permissions work correctly.
4. **Mount Options**: Leave blank (optimized defaults).

> [!TIP]
> Use the "root" password set during creation only for the initial console login to install dependencies.
