# Gitea Setup

> [!NOTE]
> #Gitea #Docker #Git #ReverseProxy #Infrastructure

## 1. Description

Gitea is a lightweight, self-hosted Git service providing code hosting, code review, issue tracking, and repository management. In this infrastructure, it serves as the central version-control repository across private development workloads.

## 2. Architecture & Network

- **Host Node**: `docker-services` (`[HOMELAB-IP]`, VM 100)
- **Deployment**: Hardened Docker Compose container orchestrated via Portainer
- **Reverse Proxy**: Caddy (`[REVERSE-PROXY-IP]`) terminating TLS 1.3
- **Access Policy**: LAN & VPN only (`access_policy_lan`), enforcing strict 403 blocks against WAN requests
- **Git Transport**: Smart HTTP/HTTPS with Personal Access Tokens (PAT); external SSH disabled for maximum isolation

## 3. Storage & Persistence

| Path | Purpose | Backup Policy |
| :--- | :--- | :--- |
| `/srv/gitea` | Persistent data root (repositories, SQLite database, custom templates) | Daily Proxmox Backup Server (PBS) & Kopia `/srv` snapshots |
| `/srv/gitea/.env` | Runtime environment secrets (mode `600`) | Managed via SOPS age encryption in GitOps |

## 4. Git Client Authentication

Client machines on the local network (`lab-vm`, `scratch-pc`, `ai-tools`, workstations) authenticate over HTTPS:

1. Generate a Personal Access Token (PAT) within the Gitea Web UI under **Settings → Applications**.
2. Store the credentials using the Git credential helper:
   ```bash
   git config --global credential.helper store
   ```
3. Clone or push repositories using the standard HTTPS URL:
   ```bash
   git clone https://gitea.[DOMAIN]/username/repository.git
   ```
