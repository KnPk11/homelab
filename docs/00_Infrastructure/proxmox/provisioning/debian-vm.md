> [!NOTE]
> **Tags:** #Proxmox #Infrastructure #Provisioning #Debian #Linux #VM

# Debian VM Provisioning Guide

This guide provides a standard blueprint for creating a Debian-based virtual machine on Proxmox.

## Phase 1: Obtain the Installation Media

1. **Download Debian**: Fetch the **Netinst ISO** from the [official Debian website](https://www.debian.org/download).
2. **Upload to Proxmox**:
    - Select your **local** storage in the Proxmox sidebar.
    - Select **ISO Images** → **Upload**.
    - Select your Debian ISO and complete the upload.

---

## Phase 2: Create the VM (Recommended Settings)

Click **Create VM** and follow these tab-specific recommendations:

### 1. General
- **Name**: Give it a descriptive name (e.g., `debian-server`).
- **VM ID**: Leave as default unless managing a specific ID range.

### 2. OS
- **ISO image**: Select the Debian ISO uploaded in Phase 1.
- **Guest OS**: Type: `Linux`, Version: `6.x - 2.6 Kernel`.

### 3. System
- **SCSI Controller**: `VirtIO SCSI single`.
- **Qemu Agent**: **Check this box**. (Required for Proxmox to see IP addresses and handle clean shutdowns).

### 4. Disks
- **Storage**: `local-lvm` (or your preferred thin pool).
- **Disk Size**: 32GB is a good standard.
- **SSD Emulation**: **Check this box** (Optimizes for flash storage).
- **Discard**: **Check this box** (Crucial for reclaiming space).

### 5. CPU
- **Cores**: 2 (Adjust based on workload).
- **Type**: `host` (Provides best performance by passing through host CPU features).

### 6. Memory
- **Memory (MiB)**: 2048 (2GB) is plenty for a headless server.
- **Ballooning Device**: Keep checked.

### 7. Network
- **Bridge**: `vmbr0`.
- **Model**: `VirtIO (paravirtualized)`.

---

## Phase 3: Install Debian

Launch the **Console** and select **Graphical Install**.

1. **Language & Region**: Select your local preferences.
2. **Hostname**: Set a unique hostname (e.g., `homelab-01`).
3. **Users & Passwords**:
    - **Root Password**: Set a strong password.
    - **User Account**: Create a standard user `[USER]` and set a password.
4. **Partitioning**:
    - Select **Guided - use entire disk**.
    - Select **All files in one partition**.
    - **Confirm**: You must select **YES** to write changes to disk.
5. **Software Selection**:
    - **Uncheck**: `Debian desktop environment` and `GNOME`.
    - **Check**: `SSH server` and `Standard system utilities`.
6. **GRUB**: Install the GRUB boot loader to your primary drive (`/dev/sda`).

---

## Phase 4: Post-Install Configuration

### 1. Install QEMU Guest Agent
Log in as root or use `su -` and run:

```bash
apt update
apt install qemu-guest-agent -y
systemctl start qemu-guest-agent
systemctl enable qemu-guest-agent
```

### 2. Network Wait Override (Optional)
If the "Wait for Network" service fails at boot, apply this fix:

```bash
sudo systemctl edit systemd-networkd-wait-online.service
```

Add the following block:
```ini
[Service] 
ExecStart= 
ExecStart=/usr/lib/systemd/systemd-networkd-wait-online --interface=ens18 --timeout=30
```

> [!TIP]
> By default, Debian blocks root login via SSH. Log in as your standard user and use `su -` or install `sudo`.
