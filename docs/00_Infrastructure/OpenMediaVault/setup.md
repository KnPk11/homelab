# OpenMediaVault Setup & Configuration

> [!NOTE]
> **Tags:** #OpenMediaVault #FileSharing #NFS #SMB

## Installation

> [!TIP]
> Refer to the Debian installation in Proxmox, with a few amendments given below.

### Hardware Resources
- **Disk Size:** **16GB** or even **8GB** is enough.
- **Memory:** **2GB** is perfect for a base install.
	- _Note:_ If you plan to use the "ZFS" file system plugin inside OMV, you will want to bump this to **8GB+**.

### Initial OMV Installation
Walk through the installation steps:
1. Pick a domain such as `nas.home`.
2. Set DHCP reservation for the VM.
3. Create a new user.
4. Services -> SSH -> Enable.
5. Assign `_ssh, adm, sudo, users` and add an SSH key.

> [!TIP]
> Note that VSCode won't be able to SSH into the server because by default OMV only allows creating user folders on an external data drive.

**Enable Guest Additions:**
```bash
sudo apt install qemu-guest-agent -y
sudo systemctl start qemu-guest-agent
sudo systemctl enable qemu-guest-agent
```

### SSL Configuration (HTTPS)

**Step 1: Create the Certificate**
1. Go to **System > Certificates > SSL**.
2. Click **Create (+)**.
3. Fill in the fields (you can put "OMV" or "Home" for most of them).
4. Click **Save and Apply**. 

**Step 2: Enable SSL in the Workbench**
1. Go to **System > Settings > Workbench**.
2. **Secure connection:** Change this to `SSL/TLS`.
3. **Certificate:** Select the certificate you just created.
4. **Port:** Usually defaults to `443`.
5. **Force SSL/TLS:** Check this if you want it to automatically redirect you to the secure version.
6. Click **Save and Apply**.

---

## Storage & File Systems

> [!NOTE]
> **Drives**
> OMV requires a _second_ drive to actually store your data. You have two choices here:
> 
> 1. **Virtual Data Drive:** While in this "Disks" tab, click **Add -> Hard Disk** and create a large virtual disk (e.g., 2TB) for your storage.
> 2. **Passthrough (Advanced):** If you have physical hard drives plugged into your server, you generally pass those through directly to the VM later (after the VM is created).

### Attach Data Storage
1. **Storage → Disks → Format.**
2. **Storage → File Systems → Create.**
3. Press **Mount** and select the disk.
4. **Storage → Shared Folders → Create.**
	- Format either as **BTRFS (Single mode)**, or **EXT4** for media & files drive.
	- [Discussion](https://www.reddit.com/r/OpenMediaVault/comments/1fbhbpn/ext4_vs_btrfs/) on preference.
5. **Storage → File Systems → Mount** (the little play button).

> [!WARNING]
> **Proxmox Snapshot Flag**
> To prevent data loss on a secondary drive when rolling back a VM's OS, apply the `snapshot=0` flag from the Proxmox host:
> ```bash
> qm set [VM-ID] --scsi1 [VOLUME],snapshot=0
> ```

---

## Service Setup

### SMB / CIFS Setup

> [!TIP]
> Web admin ≠ SMB user

1. **Services → SMB/CIFS → Settings → Enabled.**
2. **Storage → Shared Folders → Add:**
	- Administrator: read/write
	- Users: no access
	- Others: no access
3. **Storage → Shared Folders → Permissions → Read/Write** for your personal user.
4. **Services → SMB → Settings.**
5. **Services → SMB → Shares → Add.**

**Recommended Global SMB Settings:**

| Option              | Recommendation |
| ------------------- | -------------- |
| Home directories    | ❌ Off          |
| Inherit ACLs        | ❌ Off          |
| Inherit permissions | ❌ Off          |
| Follow symlinks     | ❌ Off          |
| Wide links          | ❌ **Off**      |
| SMB min version     | ✅ SMB3         |
| NetBIOS             | ❌ Off          |
| WINS                | ❌ Off          |
| Log level           | ✅ Normal       |

**Extra flags (Advanced Settings) for real-time file updates on Windows:**
```cfg
smb3 directory leases = no
smb2 leases = no
notify:inotify = yes
```

**Recommended Local SMB Settings:**

| Option               | Recommendation                                  |
| -------------------- | ----------------------------------------------- |
| Public               | ❌ No                                            |
| Transport encryption | ✅ Optional                                      |
| Recycle bin          | ✅ Optional; BTRFS snapshots can substitute this |
| Hosts allow          | `127.0.0.1 192.168.88. 10.5.0.`                 |

> [!TIP]
> **The space trick**
> In Samba config, ending an IP with a dot (e.g., `192.168.88.`) acts as a wildcard for that entire subnet.

**Windows Access:**
```powershell
\\<omv-ip>\<share_name>
```

> [!TIP]
> **Credential issues fix**
> ```powershell
> net use \\<omv-ip> /delete
> ```

### NFS Setup

[Useful guide](https://diymediaserver.com/post/nfs-guide/)

1. **Services → NFS → Settings → Enabled.** (Select the latest protocol).
2. **Services → NFS → Shares → Add shared folder.**
   - **Client:** `192.168.50.95/24` (or your client IP/Subnet).
   - **Privilege:** Read/Write.

**Mounting on Client:**
```bash
sudo mkdir -p /mnt/nas
sudo chattr +i /mnt/nas            # prevents writes when unmounted
```

> [!TIP]
> **Resilient Mounting**
> Ensure mount exists before services:
> ```bash
> RequiresMountsFor=/mnt/nas
> ```

**Persistent Mount (fstab):**
```bash
# Example /etc/fstab entry
192.168.50.90:/files /mnt/nas nfs _netdev,nofail,x-systemd.automount,x-systemd.idle-timeout=60,noatime,rw,soft,intr 0 0
```

---

## Identity & Permission Strategy

Allows a personal user and service accounts (Nextcloud/Docker) to share folders without conflicts.

### 1. Identity Setup (User & Group)
1. **Users → Groups → Add:** `homelab-data`.
2. **Users → Users → Add:** `srv-media`.
	- Group: Primary group `homelab-data`.
    - Shell: `/usr/sbin/nologin`.
    - Disallow account modification.
3. **Users → Users → [PERSONAL-USER] → Edit:** Add to `homelab-data` group.
4. **Storage → Shared Folders:** Privileges: Read/Write for each user and the group.

### 2. NFS Identity Flattening
**Services → NFS → Shares → Extra Options:**
`all_squash,anonuid=1001,anongid=1000` (Forces all connections to be seen as `srv-media:homelab-data`).

### 3. SMB Configuration (Personal Access)
**Services → SMB/CIFS → Shares:** Inherit ACLs: `Enabled`.

**Status Check:**
* User [PERSONAL-USER] (UID 1000)
* User srv-media (UID 1001)
* Group homelab-data (GID 1000)

---

## Data Migration & Sync

On the OMV host:
```bash
sudo chown -R srv-media:homelab-data /srv/dev-disk-by-uuid-[DISK-UUID]/files
sudo chmod 2775 /srv/dev-disk-by-uuid-[DISK-UUID]/files
```

From the homelab host:
```bash
# Initial Sync
sudo rsync -rvP --delete --perms --no-g --no-o --chmod=D2775,F664 /mnt/pool/ /mnt/nas/ > ~/sync_log.txt 2>&1 &

# Check progress as it runs
tail -f ~/sync_log.txt

# Verify Sync using checksums
sudo rsync -rvic --delete --perms --no-g --no-o --chmod=D2775,F664 /mnt/pool/ /mnt/nas/
```

---

## Testing & Troubleshooting

### Verification Checklist
1. Fire up Nextcloud.
2. Upload a test document via the Nextcloud Web UI.
3. Go to your Windows PC and try to rename that document via your mapped SMB drive.
     * **Success:** Filesystem layer handles permissions correctly.
     * **Failure:** Review "Group Write" and UMASK settings.

### Docker Service Permissions
For containers that don't cooperate, use these environment variables:
```yaml
services:
  app:
    environment:
      - PUID=1001  # Matches srv-media
      - PGID=1000  # Matches homelab-data
      - UMASK=002  # Ensures "Team-writable" permissions (775/664)
```

### BTRFS Reflinks
Efficiently share files without duplicating space:
```bash
# Example: Share a movie with Nextcloud without doubling disk usage
cp --reflink=always /srv/path/to/videos/MyVideo.mp4 /srv/path/to/nextcloud/data/user/files/MyVideo.mp4
```

---

## Security Hardening

**Zone-Based Isolation:**

| Zone              | Logic                              | Implementation                                         |
| ----------------- | ---------------------------------- | ------------------------------------------------------ |
| **Public**        | Only ports 80/443 open.            | Handled by Debian UFW script.                          |
| **Docker-to-NAS** | High-speed, IP-restricted traffic. | **NFS** restricted to the Debian Host IP only.         |
| **Management**    | LAN and VPN access only.           | SSH, Web GUI, and SMB restricted to `192.168.88.0/24`. |

**Access Hardening:**
1. **Firewall:** Run the custom OMV firewall script and apply via Web UI.
2. **Services -> SSH:** 
    - Permit root login: `No`.
    - Password authentication: `No`.
3. **Web Workbench:** Force SSL/TLS and set the appropriate **Inactivity timeout**.

> [!WARNING]
> **Firewall script**
> The script is for IPv4 only, so make sure IPv6 is disabled under Network -> Interfaces

