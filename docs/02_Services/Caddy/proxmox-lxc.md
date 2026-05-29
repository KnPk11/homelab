> [!NOTE]
> **Tags:** #Proxmox #LXC #Infrastructure #Caddy #ReverseProxy

# Caddy: Proxmox LXC Spec

This document details the specific Proxmox LXC configuration for the Caddy Reverse Proxy service.

## Provisioning Details

- **Template**: Debian 13 (Standard)
- **Unprivileged Container**: ✅ Yes
- **Nesting**: ✅ Yes

### Resource Allocation

| Resource | Value |
| :--- | :--- |
| **CPU Cores** | 2 |
| **Memory (RAM)** | 1024 MiB (1 GiB) |
| **Disk Size** | 12 GiB |

### Network Configuration

- **IPv4/CIDR**: `192.168.1.101/24` (Static)
- **Gateway**: `192.168.1.1`
- **DNS Server**: Default (Host settings)
- **Firewall**: ✅ Enabled (Managed via Proxmox)

---

## Setup Steps

1. **Create LXC**: Follow the standard Proxmox LXC creation wizard using the specs above.
2. **SSH Key**: Paste your public SSH key `[SECRET]` during creation for passwordless access.
3. **ACLs**: Leave as **Default** to ensure standard Linux permissions work correctly.
4. **Mount Options**: Leave blank (optimized defaults).

> [!TIP]
> Caddy benefits from multiple CPU cores to handle TLS handshakes and high traffic efficiently.
