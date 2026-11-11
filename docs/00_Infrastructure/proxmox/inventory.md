# Proxmox Node Inventory & Network Map

> [!NOTE]
> #Proxmox #Infrastructure #Inventory #Networking

This document provides a detailed inventory of the Proxmox Virtual Environment (PVE) and its hosted guests, along with the global network addressing scheme.

## Proxmox Host
- **Host ([PVE-NAME]):** `[PVE-IP]`
  - Primary Hypervisor running Proxmox VE.
  - Manages all virtualised compute and storage resources.

## Guest Nodes (VMs & LXCs)

For detailed hardware, CPU, RAM, and disk allocation specifications, refer to the [Proxmox Guest Allocation Matrix](guests/README.md).

| Hostname | ID | Type | Primary Role | Hardware Spec |
| :--- | :--- | :--- | :--- | :--- |
| **`docker-services`** | VM 100 | VM | Primary Docker & Portainer Application Stack | [guests/docker-services.md](guests/docker-services.md) |
| **`nas`** | VM 101 | VM | OpenMediaVault — Storage & NFS Shares | [guests/nas.md](guests/nas.md) |
| **`lab-vm`** | VM 103 | VM | Agent Workloads & Paperclip Platform | [guests/lab-vm.md](guests/lab-vm.md) |
| **`reverse-proxy`** | CT 104 | LXC | Caddy Reverse Proxy & Ingress Monitoring | [guests/reverse-proxy.md](guests/reverse-proxy.md) |
| **`ai-tools`** | CT 105 | LXC | AI Tools & Management Automation Node | [guests/ai-tools.md](guests/ai-tools.md) |
| **`dns`** | CT 106 | LXC | AdGuard Home DNS & Local Resolution | [guests/dns.md](guests/dns.md) |
| **`pulse`** | CT 107 | LXC | Pulse Multi-Host Monitoring Daemon | [guests/pulse.md](guests/pulse.md) |
| **`vpns`** | CT 108 | LXC | Tailscale & WireGuard Subnet Routers | [guests/vpns.md](guests/vpns.md) |
| **`pbs`** | CT 109 | LXC | Proxmox Backup Server Node | [guests/pbs.md](guests/pbs.md) |
| **`k8s`** | CT 110 | LXC | Lightweight Single-Node k3s Kubernetes | [guests/k8s.md](guests/k8s.md) |
| **`syslog`** | CT 111 | LXC | Centralised Off-Box Auth Log Collector | [guests/syslog.md](guests/syslog.md) |
| **`ops`** | CT 112 | LXC | Operations, DDNS & Background Automation Plane | [guests/ops.md](guests/ops.md) |

## Network Segmentation

The lab utilises VLAN segmentation to isolate untrusted services from the secure local network.

| Network | Subnet | Description |
| :--- | :--- | :--- |
| **Trusted LAN** | `[LAN-TRUSTED].0/24` | Primary workstations and secure devices. |
| **Homelab LAN** | `[LAN-SERVERS].0/24` | Servers, Infrastructure, and Management. |
| **IoT LAN** | `[LAN-IOT].0/24` | Untrusted smart devices and sensors. |
| **VPN** | `[VPN-SUBNET].0/24` | Remote access (Tailscale / Wireguard). |

> [!IMPORTANT]
> Always refer to the router configuration for the authoritative firewall rules between these segments.
