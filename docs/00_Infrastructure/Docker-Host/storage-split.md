# Docker Storage Migration

> [!NOTE]
> **Tags:** #Docker #Storage #Migration #Proxmox #LVM

A step-by-step runbook for migrating Docker, containerd, and data directories from the OS drive to a secondary storage drive.

---

## Prerequisites

- [ ] Secondary drive available and visible (`lsblk`)
- [ ] Sufficient space on new drive
- [ ] SSH access to the system
- [ ] Backup of critical data (just in case)

---

## Phase 1: Stop Services & Estimate Space

### Stop Docker

```bash
/data/scripts/Utilities/docker_ctl.sh stop
```

### Clean Up (Optional but Recommended)

```bash
sudo docker system prune -a --volumes
```

> [!WARNING]
> This removes all stopped containers, unused images, and volumes. Only run if you have a registry or can re-pull images easily.

### Estimate Required Space

```bash
sudo du -sh /var/lib/docker
sudo du -sh /var/lib/containerd
```

> [!NOTE]
> Run these commands **before** stopping Docker. If Docker is still running, the reported size will be inflated due to Docker's OverlayFS illusion.

---

## Phase 2: Prepare the New Drive

### Create Filesystem

If creating as a virtual drive in Proxmox use these flags:
- SCSI bus
- SSD Emulation
- Discard
- IO thread

```bash
sudo mkfs.ext4 /dev/sdb
```

> [!NOTE]
> Replace `/dev/sdb` with your actual drive path from `lsblk`.

### Configure Permanent Mount

```bash
sudo blkid /dev/sdb
```

Add to `/etc/fstab`:

```bash
UUID=[DISK-UUID] /mnt/appdata ext4 defaults,discard 0 2
```

### Mount and Create Directories

```bash
sudo systemctl daemon-reload
sudo mount /mnt/appdata

sudo mkdir -p /mnt/appdata/docker
sudo mkdir -p /mnt/appdata/containerd
sudo mkdir /mnt/appdata/srv
sudo mkdir /mnt/appdata/data
```

---

## Phase 3: Migrate Data

```bash
sudo rsync -aP /var/lib/docker/    /mnt/appdata/docker/
sudo rsync -aP /var/lib/containerd/ /mnt/appdata/containerd/
sudo rsync -aP /srv/               /mnt/appdata/srv/
sudo rsync -aP /data/              /mnt/appdata/data/
```

> [!TIP]
> The `-a` flag preserves permissions and timestamps. `-P` shows progress for large transfers.

---

## Phase 4: Create Anchor Points

Rename the old directories:

```bash
sudo mv /var/lib/docker    /var/lib/docker.bak
sudo mv /var/lib/containerd /var/lib/containerd.bak
sudo mv /srv               /srv.bak
sudo mv /data              /data.bak
```

Create new empty directories:

```bash
sudo mkdir -p /var/lib/docker
sudo mkdir -p /var/lib/containerd
sudo mkdir /srv
sudo mkdir /data
```

---

## Phase 5: Configure Bind Mounts

Add these lines to `/etc/fstab` beneath the base mount:

```bash
/mnt/appdata/docker      /var/lib/docker      none  bind  0  0
/mnt/appdata/containerd  /var/lib/containerd  none  bind  0  0
/mnt/appdata/srv         /srv                 none  bind  0  0
/mnt/appdata/data        /data                none  bind  0  0
```

Apply and verify:

```bash
sudo systemctl daemon-reload
sudo mount -a
df -h
```

> [!SUCCESS]
> You should see your secondary drive listed multiple times, seamlessly projecting its folders across your OS.

---

## Phase 6: Restart & Verify

```bash
/data/scripts/Utilities/docker_ctl.sh start
```

Verify containers start correctly and volumes are accessible.

---

## Phase 7: Cleanup (After Confirmation)

Once everything works, remove the old directories:

```bash
sudo rm -rf /var/lib/docker.bak
sudo rm -rf /var/lib/containerd.bak
sudo rm -rf /srv.bak
sudo rm -rf /data.bak
```

Tell the hypervisor that space has been freed:

```bash
sudo fstrim -av
```

---

## Proxmox-Specific: Shrink the Original Drive

> [!NOTE]
> Perform these steps only after confirming the migration works.

### 1. GParted (Live USB)

Resize the drive conservatively, leaving just a little free space. This will be useful to prevent errors when running the Proxmox `lvreduce` command.

### 2. Proxmox: Reduce LVM

```bash
lvm lvreduce -L -48g pve/vm-100-disk-0
qm rescan
```

> [!WARNING]
> Reduce by an amount **less than or equal** to the unallocated space set in GParted.

### 3. GParted: Final Resize

Resize the main partition back, leaving a few GB for swap. Create and map the swap partition.
