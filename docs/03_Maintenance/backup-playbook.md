# Homelab Backup Playbook

> [!NOTE]
> #Backup #Maintenance #Kopia #Proxmox #PBS #MikroTik

## 📖 1. Description

Operator playbook for **backing up and restoring** the homelab, plus light cleanup that usually runs before or after a backup window. It covers:

| Layer | What | Where it lives |
| :--- | :--- | :--- |
| **Configs & secrets** | Live `/srv` envs, keys, node configs | On-demand scrape → `secrets_vault` |
| **Router settings** | MikroTik config | Automated export + optional binary backup |
| **Logs** | Large media libraries | Separate NAS/SMB sync |
| **App data (docker-services)** | `/srv`, `/data`, Docker volumes via **Kopia** | Repo on NAS; client config on the host |
| **Guests** | VMs/CTs | Proxmox Backup Server (`pbs-linux`) |
| **Media / bulk NAS** | Large media libraries | Separate NAS/SMB sync |

## ✅ 2. Pre-backup checklist

Run through these before a planned backup window:

1. **Repository**: Commit and push any intentional changes.
2. **Optional app exports**:
   - **Vaultwarden / Bitwarden**: encrypted JSON export, password-protected.
   - **AnyType**: File → Export Space → Any-Block / Protobuf (enable options you need).

## 🧹 3. Cleanup

### 3.1 fstrim (reclaim free space on thin disks)

**Check timer status** (run on Proxmox host and each VM):

```bash
systemctl is-enabled fstrim.timer
systemctl status fstrim.timer --no-pager
systemctl list-timers fstrim.timer --no-pager
```

**Enable if missing** (VMs / host only):

```bash
sudo systemctl enable --now fstrim.timer
```

**Run** (safe; can take a while on large disks):

```bash
sudo fstrim -av
```

### 3.2 VS Code remote sessions

```bash
# How large is it?
du -sh ~/.vscode-server 2>/dev/null
du -sh ~/.vscode-server/code-* 2>/dev/null | sort -h

# List builds (newest mtime last is a reasonable “current” guess — verify before delete)
ls -lt ~/.vscode-server | head
```

> [!TIP]
> **While connected:** Prefer deleting only builds that are clearly old.

### 3.3 Docker clean-up

Optional hygiene in Portainer (or CLI):

- **Images** — prune unused images; keep large tags for stacks you stop often (e.g. Airflow) to avoid rebuilds.
- **Volumes** — only remove named volumes you are sure are disposable; even if shown as inactive due to a stack being offline.
- **Test DBs** — drop large throwaway PostgreSQL (or similar) volumes when finished.

### 3.4 Nextcloud `occ` janitor (optional)

Run inside the Nextcloud app container:

```bash
# Orphaned previews
php occ preview:cleanup

# Deleted files and old file versions
php occ trashbin:cleanup --all-users
php occ versions:cleanup

# Remove a user (then remove leftover data dir if required)
php occ user:delete [OLD-USERNAME]
# sudo rm -rf /var/lib/docker/volumes/nextcloud_nextcloud_data/_data/data/[OLD-USERNAME]

# Truncate a runaway log (path may vary)
truncate -s 0 /path/to/nextcloud.log
```

## 🔐 4. Configs and secrets

Live secrets and host-only configs - run the on-demand scraper after unlocking God Mode SSH:

```bash
ai-key-unlock
# ensure agent is loaded in this shell
source ~/.ssh/ai-key-agent.sh

/opt/dev/homelab_repo/nodes/ai-tools/services/configs-and-secrets-backup/scrape_configs_and_secrets.sh
```

- **Output:** `/opt/dev/secrets_vault/configs_and_secrets/` (layout mirrors remote paths).
- **Not for cron** — run when needed, then move/copy the vault offline.

## 🌐 5. Router settings

### Automated export (preferred)

Cron on **ai-tools** runs `capture-mikrotik-config.sh` every few hours:

- Uses `svc_backup` (or configured SSH user) against the router.
- Writes timestamped `.rsc` exports under `/opt/dev/secrets_vault/mikrotik-backups/`.
- Human-readable RouterOS script; treat as sensitive and keep in the vault.

### Manual binary backup (full state)

Includes secrets; not human-readable:

```bash
/system backup save name=mybackup password=[SECRET]
```

### Manual text export

```bash
/export file=fullconfig
```

Download from **Files** in Winbox/WebFig and store offline.

## 🐳 6. Docker host — Kopia (inactive)

Runs on **docker-services**. Scripts are tracked in Git and symlinked under `/opt/scripts/Backups/Kopia/`. Repository data sits on the NAS; **client config and password stay on the host** (not in Git).

| Path | Role |
| :--- | :--- |
| `/opt/scripts/Backups/Kopia/homelab_backup_kopia.sh` | Backup runner (symlink) |
| `/opt/scripts/Backups/Kopia/config/main-repo.config` | Client config (secret) |
| `/opt/scripts/Backups/Kopia/config/main-repo.config.kopia-password` | Repo password (secret) |
| `/opt/scripts/Backups/Kopia/global.kopiaignore` | Exclusion list |
| `/mnt/nas/Apps/Kopia/homelab-backup` | Repository data |

### Snapshot sets

| Command | Root | Purpose |
| :--- | :--- | :--- |
| `sudo kopia-backup data` | `/data` | Host data tree |
| `sudo kopia-backup srv` | `/srv` | Service configs and app state under `/srv` |
| `sudo kopia-backup docker` | `/var/lib/docker/volumes` | Named Docker volumes |
| `sudo kopia-backup maintenance` | — | Kopia maintenance |

### Typical backup window

Stop Docker only if you need consistent volume snapshots for write-heavy stacks (recommended for a full `docker` pass):

```bash
sudo /opt/homelab-repo/nodes/docker-services/scripts/docker_ctl.sh stop

sudo kopia-backup data
sudo kopia-backup srv
sudo kopia-backup docker
sudo kopia-backup maintenance

sudo /opt/homelab-repo/nodes/docker-services/scripts/docker_ctl.sh start
```

If scripts are installed as documented:

```bash
sudo docker_ctl.sh stop    # if that name is on PATH
sudo kopia-backup srv
# …
sudo docker_ctl.sh start
```

Then copy or sync the **repository** on the NAS to offline/offsite media and spot-check in Kopia UI or CLI.

### Verify

```bash
CFG=/opt/scripts/Backups/Kopia/config/main-repo.config

sudo kopia --config-file "$CFG" repository status
sudo kopia --config-file "$CFG" snapshot list
sudo kopia --config-file "$CFG" content stats
```

Policy for a path (example):

```bash
sudo kopia --config-file "$CFG" policy get /srv
```

### Restore (outline)

1. Ensure client config + password are present under `/opt/scripts/Backups/Kopia/config/`.
2. Confirm repository path is reachable (`/mnt/nas/Apps/Kopia/homelab-backup`).
3. List snapshots, pick an ID, restore into a **staging** path first when possible:

```bash
CFG=/opt/scripts/Backups/Kopia/config/main-repo.config
sudo kopia --config-file "$CFG" snapshot list
sudo kopia --config-file "$CFG" snapshot restore [SNAPSHOT-ID] /tmp/restore-staging/
```

4. Move data into the live path (e.g. a Docker volume) only after checking ownership and service stop/start.

> [!WARNING]
> Restoring directly over a live volume with the stack running can corrupt databases. Stop the stack (or the single service) first.

Exclusions and rationale: [Appendix A](#appendix-a-kopia-exclusions).

## 🛡️ 7. Proxmox Backup Server

Primary guest protection is **PBS** datastore **`pbs-linux`** (path on PBS host: `/mnt/datastore/pbs`). Schedule and retention are configured on PBS; see [Proxmox Backup Server](../00_Infrastructure/proxmox/proxmox-backup-server.md).

> [!NOTE]
> Older workflow used `vzdump` files under host dump paths. Prefer PBS.

### Offline / secondary copy of the datastore

When taking an offline copy of verified PBS data:

1. Confirm PBS verify jobs and schedules look healthy.
2. From a backup PC, sync the datastore (e.g. WinSCP/FreeFileSync/rsync) from the PBS host path for **`pbs-linux`** to local offline storage.
3. Prefer **mirror** with deletion on the destination.
4. Optionally count files/dirs before and after sync (PBS trees are large because of `.chunks`).

## 📜 8. Logs (optional)

- Sync or backup logs over **SMB** to offsite storage.

## 🗄️ 9. NAS and bulk media (optional)

Large media libraries from the NAS VM are **not** synced.

- Sync or backup NAS shares over **SMB** to offsite storage.


---

## 📎 Appendix A: Kopia exclusions

Tracked ignore file: `nodes/docker-services/scripts/kopia/global.kopiaignore` (symlinked into the runtime dir). Keep this appendix and the live ignore list in sync when you change policy.

### Example ignore patterns

```cfg
# Data exclusions
scripts/Downloads/Old/yt-dlp/logs

# SRV exclusions
pinchflat/config/
adguard/work/data/querylog.json.*
pihole/etc-pihole/pihole-FTL.db
jellyfin/config/data/metadata
loki/data/chunks/fake
filebrowser-quantum/tmp
qbittorrentvpn/supervisord.log.*

# Docker volume exclusions
influxdb_influxdb-data/_data/engine/
nextcloud_nextcloud_data/_data/data/appdata_oc4oguxacss8/preview
nextcloud_nextcloud_data/_data/data/nextcloud.log.*
open-webui_openwebui_data/_data/uploads

# Common
**/cache/**
**/preview/**
**/*.tmp
**/*.temp
**/*.swp
**/*.log.*
```

### Rationale

| Service            | Target Path / File                      | Rationale                                                                         |
| :----------------- | :-------------------------------------- | :-------------------------------------------------------------------------------- |
| **Pinchflat**      | `pinchflat/config/db/pinchflat.db`      | ⚠️ Large database; contains settings but grows significantly.                     |
| **AdGuard**        | `querylog.json.*`                       | ✅ Rotated logs; safe to exclude.                                                  |
| **Pi-hole**        | `pihole-FTL.db`                         | ✅ Query history; non-essential for restoration.                                   |
| **Jellyfin**       | `.../data/metadata`                     | ℹ️ Posters and NFOs; excluding forces a full library rescan.                      |
| **InfluxDB**       | `.../_data/engine/`                     | ✅ Historical logs; safe if `.bolt` and `.sqlite` are kept.                        |
| **Loki**           | `.../chunks/fake`                       | ✅ Historical logs; dashboard history will be lost.                                |
| **File Browser**   | `.../tmp`                               | ✅ Temporary staging area; 100% safe to exclude.                                   |
| **qBittorrentVPN** | `.../supervisord.log.*`                 | ✅ Rotated logs; safe to exclude.                                                  |
| **Uptime Kuma**    | `.../ib_logfile0`<br>`.../ibdata1`      | 🛑 **Critical**: Mutually dependent. Exclude both or neither to avoid corruption. |
| **Open WebUI**     | `.../_data/uploads`                     | ℹ️ AI analysis uploads; only exclude if originals exist elsewhere.                |
| **Nextcloud**      | `.../mariadb/ib_logfile0`               | 🛑 **Critical**: Redo Log; required for database integrity.                       |
| **Nextcloud**      | `.../preview/`<br>`.../nextcloud.log.*` | ✅ Thumbnails and rotated logs; safe to exclude.                                   |
