# 🚀 Homelab Blueprint: Infrastructure & Service Documentation

This repository is the central "Source of Truth" for my private cloud infrastructure. It transitions my homelab from a monolithic "manual" setup to a mature, distributed, and documented architecture.

---

## 🏗️ The Architecture
My lab is built on a **Defense-in-Depth** philosophy, utilizing a dual-router physical isolation strategy and a Proxmox hypervisor layer.

```mermaid
graph TD
    subgraph WAN["🌐 Public Internet"]
        Caddy["LXC: Caddy Reverse Proxy"]
    end
    
    subgraph Network["🛡️ Network Layer (MikroTik)"]
        VLAN_IOT["VLAN: IoT (Isolated)"]
        VLAN_LAB["VLAN: Homelab (Untrusted)"]
        VLAN_LAN["VLAN: Trusted LAN"]
    end

    subgraph Compute["🖥️ Proxmox Hypervisor"]
        L1[Infrastructure: AdGuard, Caddy, AI Tools]
        L2[Apps: Nextcloud, Immich, Docker VM]
        L3[Storage: OpenMediaVault NAS]
    end

    WAN --> Caddy
    Caddy --> Network
    Network --> Compute
```

---

## 📂 Repository Index
The repository is organized following the dependency chain of a professional environment:

- **[00_Infrastructure](./docs/00_Infrastructure/)**: Bare-metal specs, Inventory, and Hypervisor/OS setup guides.
- **[01_Network](./docs/01_Network/)**: Routing logic, VLAN segmentation, and VPN configs.
- **[02_Services](./docs/02_Services/)**: Modular runbooks for self-hosted applications.
- **[03_Maintenance](./docs/03_Maintenance/)**: Tiered backup strategy and exclusion rules.
- **[04_Resources](./docs/04_Resources/)**: Linux CLI cheat sheets and external documentation links.
- **[05_AI_Tools](./docs/05_AI_Tools/)**: Agentic AI setup and IDE integrations.
- **[99_Archive](./docs/99_Archive/)**: Historical research and deprecated setups.

---

## 🛠️ Tech Stack
*   **Hypervisor:** Proxmox VE
*   **Storage:** OpenMediaVault (SMB/NFS)
*   **Networking:** MikroTik RouterOS (VLANs)
*   **Ingress:** Caddy (Automated TLS)
*   **AI:** Gemini CLI, OpenClaw

---

## 🎯 Design Philosophy
1.  **Security-First:** All services are assumed "untrusted" and isolated from the primary workstation LAN.
2.  **Stateless Compute:** VMs are treated as disposable; all persistent data is centrally managed on the NAS.
3.  **Documentation-Driven:** If it isn't documented, it doesn't exist. This repo allows for a 100% rebuild of the lab from scratch.

---
*Created and maintained with the help of Gemini CLI Agent.*
