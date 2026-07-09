# Backup and Maintenance Guide

> [!NOTE]
> **Tags:** #Backup #Maintenance #Kopia #Proxmox #Mikrotik

## 1. Description

A comprehensive playbook for performing routine maintenance, cleaning up services, and executing backups across the homelab infrastructure using Kopia and native tools.

## 2. Prerequisites & Cleanup

1. Update Obsidian notes (e.g., Docker Compose stacks).
2. Backup Portainer stacks: **Settings** -> **General** -> **Download backup**.
3. Export Bitwarden vault as JSON (encrypted) -> Password protected.
4. Run the log processing script:
   
   ```bash
   sudo /data/scripts/Logs/process_logs.sh
   ```
   - Back up the logs drive if needed.
5. Clean up unused Docker images and volumes in Portainer's web menu:
   - **Images**: Don't delete big ones belonging to important stacks that are stopped, to avoid re-pulling and re-building (e.g., Airflow). Make sure to rely on tags for important images.
   - **Volumes**: Be especially careful with removing named volumes belonging to inactive stacks. Sort by stack name and unselect those.
   - **Test databases**: Consider removing big test databases such as PostgreSQL.

## 3. Service-Specific Clean-Up

### Nextcloud's `occ` Janitor

- **Previews**: `php occ preview:cleanup` - Deletes orphaned preview files.
- **Trash & Versions**:
  - `php occ trashbin:cleanup --all-users` - Clears deleted files.
  - `php occ versions:cleanup` - Removes old file versions.
- **Delete Old Accounts**:
  - `php occ user:delete <old_username>`
  - `sudo rm -rf /var/lib/docker/volumes/nextcloud_nextcloud_data/_data/data/<old_username>`
- **Logs**: `truncate -s 0 /path/to/nextcloud.log` - Empties log file.

## 4. Self-Hosted Services Backup (Kopia)

### Creating Backups

1. Stop the Docker service using a custom script:
   
   ```bash
   /data/scripts/Utilities/docker_ctl.sh stop
   ```

2. Run the backup command:
   
   ```bash
   sudo /data/scripts/Backups/Kopia/homelab_backup_kopia.sh
   ```

3. Restart the Docker service:
   
   ```bash
   /data/scripts/Utilities/docker_ctl.sh start
   ```

4. Backup the target repository externally and test in the Kopia GUI.

### Verifying Data

View snapshots for a specific tag:

```bash
sudo kopia snapshot list --tags type:data --config-file /data/scripts/Kopia/config/main-repo.config
```

Check policies for each tag:

```bash
sudo kopia --config-file /data/scripts/Kopia/config/main-repo.config policy get /data
```

Check archival stats:

```bash
sudo kopia --config-file /data/scripts/Kopia/config/main-repo.config content stats
```

### Restoring with Kopia

1. First, mount the repository:
   
   ```bash
   sudo kopia repository connect filesystem --path /mnt/pool/Apps/Kopia/homelab-backup
   ```

2. Grab the unique ID of the folder to be restored and follow this example:
   
   ```bash
   sudo kopia snapshot restore [SNAPSHOT-ID] /var/lib/docker/volumes/nextcloud_nextcloud_data/
   ```

## 5. Proxmox Backups

Run the trim command before a Proxmox backup to ensure a smaller backup image size:

```bash
sudo fstrim -av
```

Find the backup location:

```bash
find / -name "vzdump-qemu-100-2026_*"
```

Copy a backup from Proxmox:

```bash
# LXCs
scp root@[PROXMOX-IP]:/mnt/newdrive/dump/vzdump-lxc* [LOCAL-BACKUP-PATH]

# VMs
scp root@[PROXMOX-IP]:/mnt/newdrive/dump/vzdump-qemu* [LOCAL-BACKUP-PATH]
```

Copy a backup to Proxmox:

```bash
scp [LOCAL-BACKUP-PATH]/vzdump-qemu-100-2026_02_08-00_54_24.vma.zst root@[PROXMOX-IP]:/var/lib/vz/dump/
```

Restore backup as a new VM. Make sure to pick a new ID!

```bash
qmrestore /var/lib/vz/dump/vzdump-qemu-100-2026_02_08-00_54_24.vma.zst 102
```

## 6. Media Share Backup

1. Mount an external drive:
   
   ```bash
   sudo mount /dev/sda1 /mnt/flash1
   ```

2. Run the `Backup Media Share.sh` script.
3. Unmount the drive once finished:
   
   ```bash
   sudo umount /mnt/flash1
   ```

> [!TIP]
> Or just sync as normal using an SMB share.

## 7. MikroTik Backup

### Method 1: Automated config capture

A cron job on `ai-tools-105` pulls a gitignored RouterOS export every 3 hours and:
- Saves a full local backup to `nodes/ai-tools-105/backups/mikrotik-config-export.rsc`

### Method 2: Binary system backup

```bash
/system backup save name=mybackup password=[SECRET]
```

Download under **Files → File** and store securely. Restores the full router state including secrets, but is not human-readable.

### Method 3: Configuration file export (manual)

```bash
/export file=fullconfig
```

Download under **Files → File**. Human-readable RouterOS script, but secrets are excluded.

## 8. Appendix A: Kopia Exclusions

### Exclusions Configuration

```cfg
# Data exclusions
scripts/Downloads/Old/yt-dlp/logs

# SRV Exclusions
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

# Other common homelab exclusions
**/cache/**
**/preview/**
**/*.tmp
**/*.temp
**/*.swp
**/*.log.*
```

### Exclusions List and Rationale

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
