# 🖥️ KP's Homelab Blueprint: Infrastructure & Documentation

This repository is the central "Source of Truth" for my private cloud infrastructure. It transitions my homelab from a monolithic "manual" setup to a mature, distributed, GitOps-driven architecture.

## 🖼️ Lab UI

Sanitised views of the Dashy control surfaces — public entrypoint vs private service catalogue.

| Public entrypoint | Private catalogue |
| :---: | :---: |
| ![Public Dashy landing page](docs/assets/screenshots/dashy-public-landing.jpg) | ![Private Dashy service catalogue](docs/assets/screenshots/dashy-private-catalogue.jpg) |

## ⚙️ Tech Stack
*   **Compute:** 2× Lenovo ThinkCentre M70q Tiny (`pve1` at `192.168.50.100`; `pve2` at `192.168.50.110` — M70q Gen 2, Intel Core i5-11400T 12 threads, 31 GiB RAM, 1 TB NVMe), plus a tiny Intel Atom PC (`scratch-pc`) for light vibe-coded web services and online media sharing
*   **Hypervisor:** Proxmox VE (two standalone, unclustered nodes — `pve1` and `pve2`, Proxmox VE 9.2)
*   **Storage:** OpenMediaVault (SMB/NFS)
*   **Networking:** MikroTik (RouterOS) + ASUS (Asuswrt-Merlin)
*   **DNS:** AdGuard Home (Network-wide)
*   **Ingress:** Caddy (Automated TLS)
*   **GitOps:** Gitea (Private code & config hosting) + GitHub (Public blueprint)
*   **AI & Agents:** Antigravity (CLI / IDE), Grok Build, Paperclip, OpenClaw, Hermes

---

## 🏗️ The Architecture
My lab is built on a **Defence-in-Depth** philosophy, utilising a dual-router physical isolation strategy and two standalone (unclustered) Proxmox VE hypervisors (`pve1` at `192.168.50.100` and `pve2` at `192.168.50.110`). Workload placement across the two hosts is kept flexible and subject to change. Both nodes are identically wired into GitOps (`/opt/homelab-repo`, `sync-nodes.sh`), parameterised `pve-firewall`, Proxmox Backup Server (`pbs-linux`/`pbs-windows`), Pulse, and observability (`ssh-doorbell`, `auth-ship`, `weekly-sweep`).

```mermaid
flowchart TD
    %%{init: {"flowchart": {"padding": 8, "nodeSpacing": 20, "rankSpacing": 60}}}%%
    
    WAN("🌐 Public Internet")
    
    subgraph Network["🛡️ Network Layer (MikroTik)"]
        VLAN_MIX["VLANs: IoT (Isolated) & Homelab (Untrusted)"]
        VLAN_LAN["VLAN: Trusted LAN"]
    end

    subgraph Compute["🖥️ Proxmox Hypervisors (pve1 & pve2 — Unclustered)"]
        Caddy["Reverse Proxy (CT 104)"]
        
        subgraph DirectPorts["Direct Port Forwards"]
            MediaMTX["MediaMTX"]
            AnySync["AnySync"]
            TalkHPB["Talk-HPB"]
        end
        
        subgraph Services["Internal Services & Workloads"]
            direction TB
            L1["Core Infra: DNS, K8s, Pulse, VPNs, PBS, Syslog"]
            L5["Ops Plane: DDNS, Watch, Router Backups (CT 112)"]
            L6["AI Tools Bastion (CT 105)"]
            L2["Docker Services (VM 100) / Gitea"]
            L4["Paperclip / Hermes / OpenClaw (VM 103)"]
            L3["Storage / OMV (VM 101)"]
        end
    end

    WAN --> Network
    Network -->|Ports 80/443| Caddy
    Network -- "Port Forward" ---> DirectPorts
    Caddy -->|Internal Routing| Services

    classDef wanLayer fill:#ffe6e6,stroke:#ff6666,stroke-width:2px,color:#000;
    classDef netLayer fill:#e6f2ff,stroke:#66a3ff,stroke-width:2px,color:#000;
    classDef compLayer fill:#e6ffe6,stroke:#66ff66,stroke-width:2px,color:#000;

    class WAN wanLayer;
    class VLAN_MIX,VLAN_LAN netLayer;
    class Caddy,MediaMTX,AnySync,TalkHPB,L1,L2,L3,L4,L5,L6 compLayer;
```

---

## 💿 Storage & NAS Directory Layout
The following structure organises data across the primary storage pool (typically mounted under `/mnt/pool` using a combination of LVM, ZFS, or MergerFS).

| 📁 Root Directory | 📝 Purpose / Description | 📂 Key Subdirectories |
| :--- | :--- | :--- |
| **`Apps`** | App-specific metadata (configs, databases, local cache). | `photoprism`, `anytype` |
| **`Private`** | Sensitive and private documents (served via SMB & VPN only). | `Documents`, `Photos`, `Video`, `Audio` |
| **`Media`** | Public/Shared media for Jellyfin & Symfonium. | `Music`, `Videos` |
| **`Downloads`** | Ingest zone for new content. | `Torrents`, `Youtube` |
| **`Shared`** | Collaboration and public-facing shares. | `Users` (`[USER-A/B/C]`, `Public`, `Recycled`)<br>`Content` (`Public gallery`, `Temporary share`) |
| **`Shared_enc`** | Encrypted shares for sensitive remote access (e.g., Nextcloud). | `Users` (`[USER-A/B/C]`)<br>`Private files` |

**Usage Principles:**
1. **Separation of Concerns:** Apps store their persistent configuration in `/Apps`, keeping `/Media` and `/Private` clean for data only.
2. **Access Control:** `/Private` should never be exposed to public-facing services without additional encryption layers.

---

## 📖 Project History & Intention
What began as a brief 2014 Raspberry Pi download server experiment — soon put aside — restarted in earnest in Spring 2025 with a Raspberry Pi 5 (now powered off) and has since evolved into a comprehensive, self-hosted private cloud. Driven by a desire to bypass third-party cloud services, ensure data privacy, and learn modern architectures, this project documents continuous iteration. From early experiments with bare-metal setups and basic port forwarding, the infrastructure has matured through containerisation (Docker), network segmentation (MikroTik/VLANs), and enterprise-grade hypervisors (Proxmox). Today, it serves as a robust playground for deploying everything from self-hosted media servers and personal productivity apps, to experimenting with local LLMs and agentic AI automations.

---

## 🤖 Infrastructure as Intent
Instead of relying on rigid, syntax-heavy Infrastructure as Code (IaC) tools like Ansible, this homelab utilises **Infrastructure as Intent** and **Agentic Automation**.

By maintaining a highly structured set of Markdown notes, an AI Agent acts as the automation layer. The notes serve a dual purpose: human-readable documentation and machine-executable playbooks.
*   **Zero Syntax Overhead:** Avoids the rigid syntax of traditional IaC tools. Logic is plain English and standard shell commands.
*   **Context-Aware Execution:** The agent can diagnose, pivot, and handle unexpected errors on the fly during deployment, ensuring documentation acts as the exact executable "source of truth".

---

## 📂 Repository Index
The repository is organised following standard DevOps chapters. This structure also mirrors the centralised Obsidian Vault structure.

- **[00_Infrastructure](./docs/00_Infrastructure/)**: Bare-metal specs, Inventory, and Hypervisor/OS setup guides.
- **[01_Network](./docs/01_Network/)**: Routing logic, VLAN segmentation, and VPN configs.
- **[02_Services](./docs/02_Services/)**: Modular runbooks for self-hosted applications.
- **[03_Maintenance](./docs/03_Maintenance/)**: Tiered backup strategy and exclusion rules.
- **[04_Resources](./docs/04_Resources/)**: Linux CLI cheat sheets and external documentation links.
- **[05_AI_Tools](./docs/05_AI_Tools/)**: Agentic AI setup and IDE integrations.
- **[99_Archive](./docs/99_Archive/)**: Historical research and deprecated setups.