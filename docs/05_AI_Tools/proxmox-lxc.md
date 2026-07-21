> [!NOTE]
> **Tags:** #Proxmox #LXC #Infrastructure #AI

# AI Node: Proxmox LXC Spec

This document details the specific Proxmox LXC configuration for the AI Node (`ai-tools`).

## Provisioning Details

- **Template**: Debian 13 (Standard)
- **Unprivileged Container**: ✅ Yes
- **Nesting**: ✅ Yes

### Resource Allocation

| Setting    | Value                       |
| ---------- | --------------------------- |
| OS Type    | Debian 13                   |
| CPU        | 2 cores                     |
| RAM        | 2048 MB+ (live often 4096)  |
| Swap       | 2048 MB                     |
| Disk       | 12 GB                       |
| Privileged | No (unprivileged preferred) |
| Nesting    | Yes                         |

### Network Configuration

| Setting | Value |
|---------|--------|
| **IPv4/CIDR** | Static `192.168.50.105/24` |
| **Gateway** | `192.168.50.1` (MikroTik homelab bridge) |
| **DNS** | **Do not use “Default” (host)** — host used to be router-only |
| **DNS servers** | `[ADGUARD-IP]` (AdGuard) then `1.1.1.1` (Cloudflare) |
| **Search domain** | `example.com` |
| **Firewall** | ✅ Enabled |

```bash
# On Proxmox host
pct set 105 -nameserver "[ADGUARD-IP] 1.1.1.1" -searchdomain example.com
```

Guest `/etc/resolv.conf` (PVE-managed block) should look like:

```text
# --- BEGIN PVE ---
search example.com
nameserver [ADGUARD-IP]
nameserver 1.1.1.1
# --- END PVE ---
# Primary: AdGuard (dns). Secondary: Cloudflare public DNS.
```

> [!IMPORTANT]
> **Why not the router (`192.168.50.1`) as DNS?**  
> House DHCP already uses AdGuard + `1.1.1.1`. Using the MikroTik as secondary forced Homelab → router DNS input rules and tied lab DNS to the edge box. Prefer the same dual list as DHCP.

Proxmox **host** `/etc/resolv.conf` should also prefer AdGuard + Cloudflare so new CTs with “use host DNS” do not inherit router-only DNS.

---

## Setup Steps

1. **Create LXC**: Follow the standard Proxmox LXC creation wizard using the specs above.
2. **Network**: Static IP on homelab bridge, gateway `192.168.50.1`, DNS as in the table (not Default).
3. **SSH Key**: Paste your public SSH key `[SECRET]` during creation.
4. **ACLs**: Default.
