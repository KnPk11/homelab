> [!NOTE]
> **Tags:** #Linux #Storage #Setup #fstab #MergerFS

# Storage Management & Mounting

Tactical guide for managing physical drives, partitions, and pooling layers on Linux-based nodes.

---

## Mounting External Drives

### 1. Identify Disk Information
Identify the UUID of the target drive:

```bash
sudo lsblk -f
```

### 2. Configure Automatic Mounts
Edit the filesystem table to ensure the drive persists across reboots:

```bash
sudo nano /etc/fstab
```

Add the following entry (replace placeholders with specific device values):

```text
UUID=[DISK-UUID]  /mnt/[MOUNT-POINT]  ntfs-3g  defaults,uid=1000,gid=1000,umask=000,nofail  0  0
```

---

## Data Pooling (MergerFS)

When adding multiple drives to a single logical pool, use `mergerfs` to present them as a unified directory.

### 1. Create Mount Points (Branches & Pool)
Create directories for the individual source drives (branches) and the final unified mount point (pool).

```bash
sudo mkdir -p /mnt/[SOURCE-DRIVE-A]
sudo mkdir -p /mnt/[SOURCE-DRIVE-B]
sudo mkdir -p /mnt/[VIRTUAL-POOL]
```

### 2. Move Existing Data (If Migrating)
```bash
# Move contents to the new primary source drive
sudo mv /mnt/[VIRTUAL-POOL]/* /mnt/[SOURCE-DRIVE-A]/
```

### 3. Initialize the Pool
Initialize the pool by merging the underlying source branches into the target mount point:

```bash
# Standard mergerfs initialization
mergerfs /mnt/[SOURCE-DRIVE-A]:/mnt/[SOURCE-DRIVE-B] /mnt/[VIRTUAL-POOL]
```

> [!TIP]
> To make a MergerFS pool permanent, add it to your `/etc/fstab` using the `fuse.mergerfs` type.
