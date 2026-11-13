# Gitea Deployment

## Overview
Gitea is deployed on `docker-services` (`192.168.50.95`) as a hardened Docker Compose stack managed via Portainer, reverse-proxied exclusively over LAN and VPN by Caddy (`192.168.50.101`).

## Directory Structure
- **Persistent Data & Repositories**: `/srv/gitea` (mapped to `/data` in container, owned by `1000:1000`)
- **Runtime Environment**: `/srv/gitea/.env` (mode `600`)
- **Docker Network**: `caddy_private`

## Deployment Steps

1. Decrypt runtime environment file on the host:
   ```bash
   cd /opt/homelab-repo/nodes/docker-services/services/gitea
   sudo ./deploy-app.sh
   ```
2. Deploy or update stack in Portainer:
   - **Name**: `gitea`
   - **Repository URL**: `https://github.com/KnPk11/homelab`
   - **Compose path**: `nodes/docker-services/services/gitea/docker-compose.yml`

## Automated Backups

Gitea organises an atomic `gitea dump` pipeline targeting OMV NFS storage (`/mnt/nas/Apps/gitea_backups`).
To install or refresh the backup timer:
```bash
cd /opt/homelab-repo/nodes/docker-services/services/gitea/backup
sudo ./install.sh
```

