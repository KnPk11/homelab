# Gitea Backup Suite

Automated daily backup service for the Gitea container to OMV NFS storage (`/mnt/nas/Apps/gitea_backups`).

## Components
* `gitea-backup.sh`: Executes an atomic `gitea dump` inside the container, copies the archive to `/mnt/nas/Apps/gitea_backups/`, maintains `gitea-latest.zip`, and prunes snapshots older than 14 days.
* `gitea-backup.service`: Oneshot systemd service running `/usr/local/bin/gitea-backup.sh`.
* `gitea-backup.timer`: Systemd timer firing daily at 02:00:00 UTC (with a randomised delay of up to 10 minutes).
* `install.sh`: Installs the script to `/usr/local/bin/` and enables the systemd timer.

## Installation
```bash
sudo ./install.sh
```

## Manual Backup Run
```bash
sudo systemctl start gitea-backup.service
journalctl -u gitea-backup.service -n 50 --no-pager
```
