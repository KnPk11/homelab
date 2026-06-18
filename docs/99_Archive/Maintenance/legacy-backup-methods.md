# Legacy Backup Methods

> [!NOTE]
> **Tags:** #Archive #Backup #Rsync #Restic #RaspberryPi

## 1. Description

An archive of deprecated backup methodologies previously utilised in the homelab environment prior to the adoption of Kopia and Proxmox.

## 2. Restic (Legacy Primary Backup)

Restic was previously used for backups before transitioning to Kopia.

### Commands

```bash
# Initialize a repository
restic init -r /home/[USER]/Desktop/homelab_backup/Notes

# Backup Notes directory (tagged as "notes")
restic -r /home/[USER]/Desktop/homelab_backup/Notes backup /home/[USER]/Desktop/Notes --tag notes

# List snapshots
restic -r /home/[USER]/Desktop/homelab_backup/Notes snapshots

# Apply retention rules (keep last 100 snapshots, prune old ones)
restic -r /home/[USER]/Desktop/homelab_backup/Notes forget --tag notes --keep-last 100 --prune

# Restore snapshot by ID into Notes directory
restic -r /home/[USER]/Desktop/homelab_backup/Notes restore abcd1234 --target /home/[USER]/Desktop/Notes

# Delete snapshot by ID
restic -r /home/[USER]/Desktop/homelab_backup/Notes forget 2fcfa97c --prune

# Delete all snapshots
restic -r /home/[USER]/Desktop/homelab_backup/Notes forget --all --prune

# Load backend credentials (e.g., for Storj)
source /data/secrets/storj.env
```

### Restic Benchmark Rationale

> [!INFO] Restic backup stats
> Note on using Restic to back up directories directly versus backing up tar archives of each volume. The tar method is much slower, requires an extra step, and takes up more storage, but it preserves file permission flags better.
> 
> Docker volumes (direct): `1,689 MB` -> `1,720 MB` = `31 MB`
> Docker Volumes (tar): `1,557 MB` -> `2,987 MB` = `1,430 MB`
> Srv (direct): `1,539 MB` -> `1,778 MB` = `239 MB`
> Srv (tar): `1,430 MB` -> `2,111 MB` = `681 MB`

## 3. Rsync Bare-Metal Backup

A method for cloning a live OS to a mounted SD card.

1. **Prerequisites**: Ensure all necessary prerequisites are met.
2. **Mount the Backup Card**:
   
   ```bash
   sudo mount /dev/sda2 /mnt/sd_os_clone
   ```

3. **Stop Docker Services**:
   
   ```bash
   /data/scripts/docker-ctl.sh stop
   ```

4. **Execute Rsync**: Run the backup from the root directory:
   
   ```bash
   sudo rsync -aAXH --delete --no-whole-file --inplace --info=progress2 --no-inc-recursive --exclude={"/boot/*","/dev/*","/proc/*","/sys/*","/tmp/*","/run/*","/mnt/*","/media/*","/lost+found/*","/srv/*","/data/*","/var/lib/docker/*"} / /mnt/sd_os_clone
   ```

5. **Restart Docker**:
   
   ```bash
   /data/scripts/docker-ctl.sh start
   ```

6. **Unmount the Drive**:
   
   ```bash
   sudo umount /mnt/sd_os_clone
   ```

> [!NOTE]
> **Flags:** The `--no-whole-file --inplace` flags run faster on slower microSD cards as `rsync` only copies changed parts of a file, though it introduces a slight risk of file corruption.

> [!NOTE]
> **Partition UUIDs:** The target drive may inherit the same UUID and partition IDs, but otherwise, update `/mnt/sd_os_clone/etc/fstab` with IDs from `sudo blkid /dev/sda2`.

> [!NOTE]
> **Performance:** Initial syncs onto a MicroSD card may take hours. Subsequent runs are significantly faster.

## 4. RaspiBackup

A dedicated utility for backing up a Raspberry Pi.

1. **Installation**:
   
   ```bash
   pushd /tmp
   curl -o install -L https://raspibackup.linux-tips-and-tricks.de/install
   sudo bash ./install
   popd
   ```

2. **Configuration**: Go through the setup configuration. Edit the config file:
   
   ```bash
   sudo nano /usr/local/etc/raspiBackup.conf
   ```

> [!NOTE]
> **Service Interruption:** Do not stop all services, as it may hang the backup. Example configuration for stopping specific services:
> ```conf
> DEFAULT_STOPSERVICES="systemctl stop docker && systemctl stop crowdsec-firewall-bouncer && systemctl stop crowdsec && systemctl stop fail2ban"
> ```

3. **Exclusions**: Add exclusions in the config:
   
   ```conf
   DEFAULT_EXCLUDE_LIST="--exclude /mnt"
   ```

4. **Execution**: Mount the target drive and run the backup:
   
   ```bash
   sudo mount /dev/sda2 /mnt/backupdrive
   sudo raspiBackup -m detailed
   ```

## 5. Win32DiskImager (Windows)

A physical cloning method.

1. Read the source drive and save the image locally using Win32DiskImager.
2. Write the newly created image to the target drive.
3. Swap the drives in the Raspberry Pi and boot it.
