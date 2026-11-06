# GitHub Backup Service

Automated daily backup suite for GitHub repositories and metadata using [Gickup](https://github.com/cooperspencer/gickup) to OMV NFS storage (`/mnt/nas/Apps/github_backups`).

## Components
* `conf.yml`: Gickup backup job specification (sources, filters, structured bare mirrors, wikis, and issue tracking).
* `github-backup.sh`: Runner script ensuring `/mnt/nas` autofs mount is active, mounting runtime configuration, and executing `buddyspencer/gickup:latest`.
* `github-backup.service`: Oneshot systemd service running `/usr/local/bin/github-backup.sh`.
* `github-backup.timer`: Daily systemd timer triggering at 03:00 UTC (staggered 1 hour after Gitea at 02:00 UTC).
* `install.sh`: Deploys configuration to `/srv/github-backup/`, runner to `/usr/local/bin/`, and enables systemd units.

## Deployment & Setup

1. Populate runtime environment on `docker-services` (`192.168.50.95`):
   ```bash
   sudo mkdir -p /srv/github-backup
   sudo nano /srv/github-backup/.env
   # GITHUB_TOKEN=github_pat_...
   sudo chmod 600 /srv/github-backup/.env
   ```

2. Run installer:
   ```bash
   cd /opt/homelab-repo/nodes/docker-services/services/github-backup
   sudo ./install.sh
   ```

3. Trigger an immediate one-off backup:
   ```bash
   sudo systemctl start github-backup.service
   journalctl -u github-backup.service -f
   ```
