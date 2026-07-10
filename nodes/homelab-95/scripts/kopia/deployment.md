# Kopia backups (homelab-95)

Tracked scripts live in Git; **client config + password stay on the host** under `/opt/scripts/Backups/Kopia/config/` (not in the clone).

### Layout

| Path | Role |
| :--- | :--- |
| `.../scripts/kopia/homelab_backup_kopia.sh` | Tracked backup runner |
| `.../scripts/kopia/initialise_repository.sh` | One-time repo create (paths already `/opt/scripts/...`) |
| `.../scripts/kopia/global.kopiaignore` | Tracked exclusion list |
| `/opt/scripts/Backups/Kopia/*.sh` | Symlinks → tracked scripts |
| `/opt/scripts/Backups/Kopia/global.kopiaignore` | Symlink → tracked ignore file |
| `/opt/scripts/Backups/Kopia/config/main-repo.config` | Client config (**secret**, host-only) |
| `/opt/scripts/Backups/Kopia/config/main-repo.config.kopia-password` | Repo password (**secret**, host-only) |
| `/opt/scripts/Backups/Kopia/logs/` | Runtime logs |
| `/mnt/nas/Apps/Kopia/homelab-backup` | Repository data on NAS |
| `/usr/local/bin/kopia-backup` | Optional CLI → backup script |

`scrape_secrets.sh` already sweeps `/opt/scripts/Backups/Kopia` for `*.config` / `*.kopia-password`.

### First-time / after nuke-and-pave

1. Pull GitOps repo to `/opt/homelab-repo`.
2. Restore `config/main-repo.config` + `.kopia-password` from the secrets vault (or run `initialise_repository.sh` only if creating a **new** empty repo).
3. Symlink tracked files into the runtime dir:
   ```bash
   REPO=/opt/homelab-repo/nodes/homelab-95/scripts/kopia
   RT=/opt/scripts/Backups/Kopia
   sudo mkdir -p "$RT/config" "$RT/logs"
   sudo ln -sfn "$REPO/homelab_backup_kopia.sh" "$RT/homelab_backup_kopia.sh"
   sudo ln -sfn "$REPO/initialise_repository.sh" "$RT/initialise_repository.sh"
   sudo ln -sfn "$REPO/global.kopiaignore" "$RT/global.kopiaignore"
   sudo chmod +x "$REPO/homelab_backup_kopia.sh" "$REPO/initialise_repository.sh"
   sudo ln -sfn "$RT/homelab_backup_kopia.sh" /usr/local/bin/kopia-backup
   ```
4. Confirm:
   ```bash
   sudo kopia --config-file /opt/scripts/Backups/Kopia/config/main-repo.config repository status
   ```

### Run backups

```bash
sudo kopia-backup data
sudo kopia-backup srv
sudo kopia-backup docker
sudo kopia-backup maintenance
```
