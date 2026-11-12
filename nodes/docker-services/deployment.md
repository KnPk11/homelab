# docker-services: Master Bootstrap Guide

> **Hostname:** `docker-services` | **IP:** `192.168.50.95` | **Proxmox:** VM 100 | **Type:** Proxmox VM (Docker & Portainer)

This node (`docker-services`, `192.168.50.95`, Proxmox VM 100) serves as the primary Docker container and Portainer application host for the homelab.

---

## 1. System Bootstrap & GitOps Model

1. **Proxmox VM Provisioning:** Review resource allocation in **[Proxmox VM Spec](../../docs/00_Infrastructure/proxmox/guests/docker-services.md)** (VM 100, 8 cores, 8 GB RAM).
2. **Universal Bootstrap:** Follow the **[Universal Node Bootstrap Guide](../../docs/00_Infrastructure/universal-node-bootstrap.md)** to install base prerequisites and link GitOps.
3. **GitOps Clone (`/opt/homelab-repo`):** Holds tracked compose files, templates, and deployment scripts only. It is strictly disposable and updated on-demand via `sync-nodes`.
4. **Runtime Secrets (`/srv/<service>/`):** Live as real files on the host only. Never commit decrypted secret files or create reverse-symlinks pointing back into the clone.
5. **Host Scripts (`/opt/scripts/...`):** Host-level operational scripts (e.g. UFW, Kopia) with dedicated runtime configuration.
6. **Compose `${VAR}` Interpolation:** Set environment variables in Portainer stack definitions or keep a host-local `.env` **only under `/srv/<service>/`** when running compose with that project directory.

### Secret Naming Conventions

| Kind | Pattern | Examples |
| :--- | :--- | :--- |
| Compose project env (domains, multi-key config) | **`/srv/<service>/.env`** | `grafana`, `n8n`, `vaultwarden`, `webdav`, `nextcloud`, `airflow`, … |
| Prefixed multi-key env (deploy scripts, not Compose auto-load) | **`/srv/<service>/<service>.env`** | `dashy/dashy.env`, `dozzle/dozzle.env` |
| Single password / token / key file | **`/srv/<service>/<name>.secret`** | `*_password.secret`, `*_token.secret`, raw tokens |
| App-specific password files | Upstream naming when required | `glances.pwd` |

> [!NOTE]
> Docker Compose only auto-loads a file named **`.env`** for `${VAR}` interpolation in compose files — do not rename those to `service.env` unless Portainer explicitly supplies the environment variables.

### Recovery / Restore Checklist

1. Pull the GitOps repository to `/opt/homelab-repo`.
2. Restore secret files under `/srv/<service>/` from the secrets vault (or recreate from `*.example` files).
3. Run service deployment scripts where required (`dashy`, `privatebin`, `mediamtx`, `dbt`, `nextcloud`, `dozzle`, `glances`, `grafana`, `gitea`).
4. Re-apply host firewall rules ([`scripts/ufw.sh`](scripts/ufw.sh)) and configure Kopia backups.
5. Deploy or update Portainer stacks from compose files in `nodes/docker-services/services/`.

---

## 2. Host Security & Firewall (UFW)

Host-local firewall rules are managed via the tracked script [`scripts/ufw.sh`](scripts/ufw.sh).

### 2.1 Firewall Installation & Deployment

1. Symlink the tracked firewall script into `/usr/local/bin/firewall`:
   ```bash
   sudo chmod +x /opt/homelab-repo/nodes/docker-services/scripts/ufw.sh
   sudo ln -sfn /opt/homelab-repo/nodes/docker-services/scripts/ufw.sh /usr/local/bin/firewall
   ```

2. Apply the firewall configuration:
   ```bash
   sudo firewall
   ```

### 2.2 Network Topology & Enforced Rules

- **Full Trust Zones:**
  - Main LAN (`192.168.88.0/24`)
  - Caddy Reverse Proxy (`192.168.50.101`)
  - AI Tools (`192.168.50.105`)
  - Docker Internal Subnet (`172.16.0.0/12`)
- **Restricted VPN Zones (`10.5.0.0/24`, `10.6.0.0/24`, `10.8.0.0/24`, `100.64.0.0/10`):**
  - SSH (`22/tcp`)
  - Cockpit Web Console (`9090/tcp`)
  - Syncthing Web UI (`8384/tcp`)
  - Syncthing Sync Protocol (`22000`)
- **Direct LAN Published Services:**
  - MediaMTX: `1935/tcp` (RTMP), `8554/tcp` (RTSP), `8888/tcp` (HLS), `8889/tcp` (WebRTC)
  - AnyType Sync: `1001:1006/tcp`, `1011:1016/udp`
  - Nextcloud Talk: `3478/tcp+udp` (STUN/TURN), `8105/tcp` (HPB)
  - qBittorrent: `8091/tcp` (Web UI)

---

## 3. Host Utilities & Maintenance

- **Docker Service Lifecycle (`scripts/docker_ctl.sh`):**
  Stops or starts Docker socket, daemon, and containerd cleanly for host maintenance without triggering systemd auto-restarts:
  ```bash
  sudo /opt/homelab-repo/nodes/docker-services/scripts/docker_ctl.sh stop
  sudo /opt/homelab-repo/nodes/docker-services/scripts/docker_ctl.sh start
  ```
- **Network Wait Helper (`scripts/wait_for_network.sh`):**
  Blocks execution until `ens18` receives static IP `192.168.50.95`. Utilised in systemd unit startup sequences.
- **Web-Compromise Watchdog:**
  Monitors Docker daemon socket events and `/proc` cgroups for unauthorised reverse shells or privileged container creation. See **[Web Compromise Watch Guide](../../shared/observability/web-compromise-watch/deployment.md)**.

---

## 4. Backup Infrastructure

| Backup Target | Type | Runbook / Script | Destination |
| :--- | :--- | :--- | :--- |
| **Kopia Backups** | Client filesystem snapshot | [scripts/kopia/deployment.md](scripts/kopia/deployment.md) | OMV NFS (`/mnt/nas/Apps/Kopia/homelab-backup`) |
| **Gitea Repositories** | Atomic dump (`gitea dump`) | [services/gitea/deployment.md](services/gitea/deployment.md) | OMV NFS (`/mnt/nas/Apps/gitea_backups`) |
| **GitHub Mirroring** | Gickup bare repo sync | [services/github-backup/deployment.md](services/github-backup/deployment.md) | OMV NFS (`/mnt/nas/Apps/github_backups`) |

---

## 5. Master Container Inventory

All services hosted on `docker-services` are catalogued below:

| Service | Primary Port(s) / Network | Compose / Service Path | Secrets / Host Config | Runbook / Setup Guide |
| :--- | :--- | :--- | :--- | :--- |
| **Airflow** | `8094:8080` (UI), `caddy_public` | `services/airflow/docker-compose.yml` | `/srv/airflow/.secrets/`, `/srv/airflow/.env` | [Section 6.1](#61-airflow-service) |
| **AnyType** | Internal | `services/anytype/docker-compose.override.yml` | `/srv/anytype-sync-logic` | [docs/02_Services/anytype](../../docs/02_Services/anytype/setup.md) |
| **AnyType Sync Logic** | `1001:1006/tcp`, `1011:1016/udp` | Host scripts | `/srv/anytype-sync-logic/.env` | [docs/02_Services/anytype](../../docs/02_Services/anytype/setup.md) |
| **Dashy** | `9102:8080`, `caddy_public`, `caddy_private` | `services/dashy/docker-compose.yml` | `/srv/dashy/dashy.env` → `config.yml` | [Section 6.3](#63-other-services-with-deploy-scripts) |
| **DBT** | CLI / Container | `services/dbt/docker-compose.yml` | `/srv/dbt/.env`, `/srv/dbt/.secrets/` | [Section 6.2](#62-dbt-service) |
| **Dozzle** | `9105:8080`, `caddy_public` | `services/dozzle/docker-compose.yml` | `/srv/dozzle/dozzle.env` → `users.yml` | [services/dozzle/deployment.md](services/dozzle/deployment.md) |
| **FileBrowser Quantum** | `9101:8080` | `services/filebrowser-quantum/docker-compose.yml` | `/srv/filebrowser-quantum/filebrowser_password.secret` | [docs/02_Services/filebrowser-quantum](../../docs/02_Services/filebrowser-quantum/setup.md) |
| **Gitea** | `3000:3000`, `2222:22`, `caddy_private` | `services/gitea/docker-compose.yml` | `/srv/gitea/.env` | [services/gitea/deployment.md](services/gitea/deployment.md) |
| **GitHub Backup** | Host systemd timer (`03:00 UTC`) | `services/github-backup/github-backup.service` | `/srv/github-backup/.env` | [services/github-backup/deployment.md](services/github-backup/deployment.md) |
| **Glances** | `61208:61208`, `caddy_private` | `services/glances/docker-compose.yml` | `/srv/glances/glances.pwd`, `glances_influx_token.secret` | [docs/02_Services/glances](../../docs/02_Services/glances/setup.md) |
| **Grafana** | `3005:3000`, `3100:3100` (Loki), `caddy_private` | `services/grafana/docker-compose.yml` | `/srv/grafana/.env`, `grafana_password.secret` | [docs/02_Services/grafana](../../docs/02_Services/grafana/setup.md) |
| **Immich** | Internal, `caddy_public` | `services/immich/docker-compose.yml` | `/srv/immich/immich_database_password.secret` | [docs/02_Services/immich](../../docs/02_Services/immich/setup.md) |
| **InfluxDB** | `8086:8086`, `caddy_private` | `services/influxdb/docker-compose.yml` | `/srv/influxdb/influxdb_password.secret` | [docs/02_Services/influxdb](../../docs/02_Services/influxdb/setup.md) |
| **Jellyfin** | `8096:8096`, `caddy_public` | `services/jellyfin/docker-compose.yml` | `/srv/jellyfin/config` | [docs/02_Services/jellyfin](../../docs/02_Services/jellyfin/setup.md) |
| **Kafka** | `9092:9092` | `services/kafka/docker-compose.yml` | Compose configuration | [docs/02_Services/kafka](../../docs/02_Services/kafka/setup.md) |
| **Lychee** | `8183:8000` | `services/lychee/docker-compose.yml` | `/srv/lychee/.env` | [docs/02_Services/lychee](../../docs/02_Services/lychee/setup.md) |
| **MediaMTX** | `8554` (RTSP), `1935` (RTMP), `8888` (HLS) | `services/mediamtx/docker-compose.yml` | `/srv/mediamtx/.env` → `mediamtx.yml` | [Section 6.3](#63-other-services-with-deploy-scripts) |
| **MeTube** | `8181:8081`, `caddy_private` | `services/metube/docker-compose.yml` | Compose configuration | [docs/02_Services/metube](../../docs/02_Services/metube/setup.md) |
| **n8n** | Internal, `caddy_private` | `services/n8n/docker-compose.yml` | `/srv/n8n/n8n_password.secret`, `n8n_secret_key.secret` | [docs/02_Services/n8n](../../docs/02_Services/n8n/setup.md) |
| **Nextcloud** | `8104:80`, `8105:8081` (HPB), `3478` (TURN) | `services/nextcloud/docker-compose.yml` | `/srv/nextcloud/.env`, `nextcloud_mysql_password.secret` | [Section 6.3](#63-other-services-with-deploy-scripts) |
| **Open-WebUI** | `3002:8080` | `services/open-webui/docker-compose.yml` | `/srv/open-webui/.env` | [docs/02_Services/open-webui](../../docs/02_Services/open-webui/setup.md) |
| **PhotoPrism** | `2342:2342`, `caddy_public` | `services/photoprism/docker-compose.yml` | `/srv/photoprism/.env`, `photoprism_password.secret` | [docs/02_Services/photoprism](../../docs/02_Services/photoprism/setup.md) |
| **Pinchflat** | Internal, `caddy_shared` (WireGuard) | `services/pinchflat/docker-compose.yml` | `/srv/pinchflat/config`, WireGuard config | [docs/02_Services/pinchflat](../../docs/02_Services/pinchflat/setup.md) |
| **Portainer** | `127.0.0.1:9443` & `192.168.50.95:9443` | `services/portainer/docker-compose.yml` | `/srv/portainer/data` | [docs/02_Services/portainer](../../docs/02_Services/portainer/setup.md) |
| **PrivateBin** | `8180:8080`, `caddy_public` | `services/privatebin/docker-compose.yml` | `/srv/privatebin/.env` → `conf.php` | [Section 6.3](#63-other-services-with-deploy-scripts) |
| **qBittorrent VPN** | `8091:8091` (UI), `8999` (Torrent TCP/UDP) | `services/qbittorrentvpn/docker-compose.yml` | `/srv/qbittorrentvpn/wireguard`, `vpn_credentials.secret` | [docs/02_Services/qbittorrentvpn](../../docs/02_Services/qbittorrentvpn/setup.md) |
| **Syncthing** | `192.168.50.95:8384` (UI), `22000`, `21027/udp` | `services/syncthing/docker-compose.yml` | `/srv/syncthing/config` | [docs/02_Services/syncthing](../../docs/02_Services/syncthing/setup.md) |
| **Tube-Sync** | `127.0.0.1:4848` | `services/tube-sync/docker-compose.yml` | `/srv/tubesync/config` | [docs/02_Services/tube-sync](../../docs/02_Services/tube-sync/setup.md) |
| **Uptime Kuma** | `3003:3001` | `services/uptime-kuma/docker-compose.yml` | `/srv/uptime-kuma/data` | [docs/02_Services/uptime-kuma](../../docs/02_Services/uptime-kuma/setup.md) |
| **Vaultwarden** | `9103:80`, `caddy_public` | `services/vaultwarden/docker-compose.yml` | `/srv/vaultwarden/.env`, `vaultwarden_admin_token.secret` | [docs/02_Services/vaultwarden](../../docs/02_Services/vaultwarden/setup.md) |
| **Web-Compromise Watch** | Internal observability daemon | `services/web-compromise-watch/telegram.env` | `/srv/web-compromise-watch/telegram.env` | [services/web-compromise-watch](services/web-compromise-watch/deployment.md) |
| **WebDAV** | `8084:80` | `services/webdav/docker-compose.yml` | `/srv/webdav/config.yaml`, `webdav_password.secret` | [docs/02_Services/webdav](../../docs/02_Services/webdav/setup.md) |
| **What's Up Docker** | `3001:3001` | `services/whats-up-docker/docker-compose.yml` | `/srv/whats-up-docker/.env` | [docs/02_Services/whats-up-docker](../../docs/02_Services/whats-up-docker/setup.md) |
| **yt-dlp WebUI** | `127.0.0.1:3033` | `services/yt-dlp-webui/docker-compose.yml` | `/srv/yt-dlp-webui/config` | [docs/02_Services/yt-dlp-webui](../../docs/02_Services/yt-dlp-webui/setup.md) |

---

## 6. Service-Specific Deployment Runbooks

### 6.1 Airflow Service

> Architectural Reference: [docs/02_Services/airflow](../../docs/02_Services/airflow/setup.md)

1. Restore secret files under `/srv/airflow/.secrets/` (`airflow_fernet_key.secret`, `airflow_jwt_secret.secret`) and `/srv/airflow/.env` (from `airflow.env`).
2. Build the custom image locally on the Docker host:
   ```bash
   docker build -t custom_airflow:3.0.4 /opt/homelab-repo/nodes/docker-services/services/airflow
   ```
3. Deploy the stack in Portainer using the compose file in the repository (`docker-compose.yml` references `custom_airflow:3.0.4` directly without `build:` so Portainer's read-only runner does not attempt in-container builds).

### 6.2 DBT Service

> Architectural Reference: [docs/02_Services/dbt](../../docs/02_Services/dbt/setup.md)

1. Place secrets on the host:
   ```bash
   sudo mkdir -p /srv/dbt/.secrets
   sudo cp /opt/homelab-repo/nodes/docker-services/services/dbt/.env.example /srv/dbt/.env
   # Populate postgres_password.secret and gcp-creds.json under /srv/dbt/.secrets/
   ```
2. Render profiles configuration:
   ```bash
   sudo /opt/homelab-repo/nodes/docker-services/services/dbt/deploy_app.sh
   ```
3. Deploy the stack in Portainer using the compose file in the repository.

### 6.3 Other Services with Deploy Scripts

The following services utilise a local `deploy_app.sh` script to render configuration templates into `/srv/<service>/` before starting containers:

| Service | Deploy Script | Secret / Environment Location |
| :--- | :--- | :--- |
| **Dashy** | `services/dashy/deploy_app.sh` | `/srv/dashy/dashy.env` |
| **Dozzle** | `services/dozzle/deploy_app.sh` | `/srv/dozzle/dozzle.env` |
| **Glances** | `services/glances/deploy_app.sh` | `/srv/glances/glances.pwd`, `glances_influx_token.secret` |
| **Grafana** | `services/grafana/deploy_app.sh` | `/srv/grafana/.env`, `grafana_password.secret` |
| **MediaMTX** | `services/mediamtx/deploy_app.sh` | `/srv/mediamtx/.env` |
| **Nextcloud** | `services/nextcloud/deploy_app.sh` | `/srv/nextcloud/.env`, `nextcloud_mysql_password.secret` |
| **PrivateBin** | `services/privatebin/deploy_app.sh` | `/srv/privatebin/.env` |

Execute any required deploy script from the repository:
```bash
cd /opt/homelab-repo/nodes/docker-services/services/<service>
sudo ./deploy_app.sh
```

---

## 7. Health Verification

Execute the following commands on `docker-services` to verify node health:

```bash
# 1. Verify firewall rules
sudo ufw status verbose

# 2. Check running Docker containers
docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"

# 3. Verify internal connectivity to Portainer
curl -kI https://127.0.0.1:9443

# 4. Check Kopia repository status
sudo kopia --config-file /opt/scripts/Backups/Kopia/config/main-repo.config repository status
```
