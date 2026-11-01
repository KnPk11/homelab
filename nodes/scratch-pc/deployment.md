# Scratch-PC-85 Master Bootstrap Guide

This node is a **bare-metal disposable dev workstation** (`scratch-pc`, `192.168.50.85`) dedicated to local web app prototyping, automated tests, and hosting self-contained services.

This node follows **Infrastructure as Intent**: prefer tracked scripts and documentation in Git; keep local disposable testbeds reproducible.

---

## 1. Node Specifications

| Item | Specification |
| :--- | :--- |
| **Hostname** | `scratch-pc` (`192.168.50.85`) |
| **Type** | Bare-metal single-board / compact workstation |
| **CPU / Arch** | x86_64 |
| **RAM** | ~1.88 GiB usable physical memory |
| **Storage** | 28.9 GiB eMMC flash (`/dev/mmcblk1`) |
| **Operating System** | Debian 13 (Trixie), systemd 257 |
| **Primary User** | `k` (service user), `root` (administration) |

---

## 2. Memory & Tiered Swap Architecture (`zram` + `/swapfile`)

`scratch-pc` is constrained by ~1.88 GiB of physical RAM and relatively slow eMMC flash storage. Under memory-heavy multi-agent workloads (such as Paperclip running its web server, embedded PostgreSQL, and spawning multiple OpenCode agent processes), memory pressure historically caused severe eMMC swap thrashing, 100% I/O wait, and complete host lockouts.

To permanently resolve this and ensure full responsiveness, the host implements a **tiered compressed RAM and fallback swap architecture**:

```text
Filename        Type        Size (KiB)    Priority    Role
/dev/zram0      partition   ~962,556      100         Ultra-fast compressed in-memory swap (Primary)
/swapfile       file        2,097,148     -2          Fallback on-disk swap (Secondary safety net)
```

### Key Benefits
* **Greatly Resurrects Heavy Services**: Heavy services such as **Paperclip** and **OpenCode** run stably without stuttering or crashing the host. Dynamic allocations and memory spikes are absorbed immediately by compressed RAM at memory bus speeds (nanosecond latency).
* **Zero eMMC Storage Thrashing**: Active working pages are held in fast `zram`, completely avoiding slow eMMC flash read/write stalls.
* **Eliminates Flash Wear**: The on-disk `/swapfile` acts strictly as an overflow safety net and remains at 0% utilisation during typical operation.

### Implementation Details

1. **Compressed In-Memory Swap (`zram`)**:
   Managed via `systemd-zram-generator` in `/etc/systemd/zram-generator.conf`:
   ```ini
   [zram0]
   zram-size = min(ram / 2, 1024)
   compression-algorithm = zstd
   swap-priority = 100
   ```
   Provides ~940 MiB of compressed RAM with `zstd`/`lz4` compression, delivering an effective ~2.5 GiB of headroom at RAM speeds.

2. **2 GiB On-Disk Fallback Swap (`/swapfile`)**:
   The legacy swap partition (`/dev/mmcblk1p3`) has been deactivated in favour of a standard 2 GiB file:
   ```bash
   fallocate -l 2G /swapfile
   chmod 600 /swapfile
   mkswap /swapfile
   swapon /swapfile
   ```
   Persisted in `/etc/fstab`:
   ```text
   /swapfile    none    swap    sw    0    0
   ```

3. **Kernel Swappiness Optimisation**:
   Configured in `/etc/sysctl.d/99-swappiness.conf`:
   ```ini
   vm.swappiness = 10
   ```
   Instructs the Linux virtual memory manager to prioritise physical memory page retention and avoid premature swapping.

---

## 3. Example Services Hosted on this Node

* **Pulse Agent**: Homelab metrics and telemetry reporting agent.
* **System Usage Stats (`ocstats`)**: Port `10482`, systemd service `ocstats.service`. Real-time telemetry dashboard for `scratch-pc` reverse-proxied via `https://ocstats.example.com`.
* **StoryCards (`storycards`)**: Port `33363`, systemd services `storycards.service`, `storycards-worker.service`, `storycards-fetcher.service`. Reverse-proxied via `https://storycards.example.com`. SQLite database snapshots and configuration backed up automatically to OpenMediaVault.
* **Homelab Command Centre (`homelab-dashboard`)**: Port `8088`, systemd service `homelab-dashboard.service`.
* **NVIDIA Model Benchmark (`nvidia-model-bench`)**: Port `8585`, systemd service `nvidia-model-bench.service`.
* **Night-Time Ambient Web App (`night-time`)**: Port `10750`, systemd unit `night-time.service`. Reverse-proxied via `https://sleep.example.com`.
* **Eurostar Price Tracker (`eurostar-tracker`)**: Port `5000`, systemd unit `eurostar-tracker.service`.
* **Markpress Preview Server (`markpress`)**: Port `8010`, systemd unit `markpress.service` (located in `/opt/web-apps-private/markpress`).

---

## 4. Firewall & Network

* Managed via [`scripts/ufw.sh`](scripts/ufw.sh).
* Reverse proxy routes through LAN Caddy (`reverse-proxy`, `192.168.50.101`).

---

## 5. Storage & Automated Backups to OpenMediaVault (PBS Protected)

Because `scratch-pc` is physical hardware not directly snapshotted by Proxmox Backup Server (PBS), stateful app data is automatically backed up to OpenMediaVault (`192.168.50.90` / VM 101):
* **NFS Automount**: `192.168.50.90:/files` mounted at `/mnt/nas` via systemd automount in `/etc/fstab`.
* **Backup Destination**: `/mnt/nas/Apps/webapp_backups/`.
* **Backup Script**: `/usr/local/bin/homelab-scratch-backup.sh`.
  - Performs clean non-blocking SQLite hot backups (`.backup`) of `storycards` (`stories.db`), storing compressed daily snapshots (`stories_*.db.gz`, 14-day retention) and `stories-latest.db`.
  - Backs up other web app files (e.g. `.env` files, encrypted `secrets.sops.env`, media and images (`uploads/`), `metadata.json`, `pending/`).
* **Systemd Timer**: `scratch-apps-backup.timer` triggers `scratch-apps-backup.service` every 4 hours (`Persistent=true`).

