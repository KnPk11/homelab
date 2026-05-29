> [!NOTE]
> **Tags:** #Proxmox #Infrastructure #Inventory #Networking

# Proxmox Node Inventory & Network Map

This document provides a detailed inventory of the Proxmox Virtual Environment (PVE) and its hosted guests, along with the global network addressing scheme.

---

## Proxmox Host
- **Host ([PVE-NAME]):** `[PVE-IP]`
  - Primary Hypervisor running Proxmox VE.
  - Manages all virtualized compute and storage resources.

---

## Guest Nodes (VMs & LXCs)

The following table lists the core nodes currently provisioned on the hypervisor.

| IP Address | Name | Type | Description |
| :--- | :--- | :--- | :--- |
| `[IP].90` | **omv-90** | VM | OpenMediaVault — Centralized Storage & Backups. |
| `[IP].91` | **openclaw-91** | VM | OpenClaw — Agentic AI Orchestration. |
| `[IP].95` | **homelab-95** | VM | Docker Host — Primary Application Stack. |
| `[IP].101` | **caddy-101** | LXC | Reverse Proxy (Caddy) & Ingress Monitoring. |
| `[IP].102` | **dns-102** | LXC | AdGuard Home — Network-wide DNS. |
| `[IP].105` | **ai-tools** | LXC | AI Tools & Management Automation Node. |
| `[IP].110` | **interview** | LXC | Disposable Postgres practice environment. |

---

## Network Segmentation

The lab utilizes VLAN segmentation to isolate untrusted services from the secure local network.

| Network | Subnet | Description |
| :--- | :--- | :--- |
| **Trusted LAN** | `[LAN-TRUSTED].0/24` | Primary workstations and secure devices. |
| **Homelab LAN** | `[LAN-SERVERS].0/24` | Servers, Infrastructure, and Management. |
| **IoT LAN** | `[LAN-IOT].0/24` | Untrusted smart devices and sensors. |
| **VPN** | `[VPN-SUBNET].0/24` | Remote access (Tailscale / Wireguard). |

> [!IMPORTANT]
> Always refer to the router configuration for the authoritative firewall rules between these segments.
