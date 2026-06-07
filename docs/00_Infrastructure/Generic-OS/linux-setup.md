> [!NOTE]
> **Tags:** #Linux #Infrastructure #Setup #Security

# Linux Setup Guide

This guide covers the initial setup and configuration for Linux-based systems in the homelab environment.

---

## IP Configuration

### Static Local IP Binding

Bind the computer to a static local IP. This ensures consistent access across the network.

> [!INFO]
> Setup varies by router; on Asus it is under **Router settings** → **LAN** → **IP Binding**.

---

## User Management & Permissions

### Superuser Rights & SUDO

Unlike Raspberry Pi OS, Debian Server disables direct root SSH by default, and the initial user is not automatically a sudoer.

1. **Become root**
   
   ```bash
   su -
   ```

2. **Install `sudo` (if missing)**
   
   ```bash
   apt update && apt install sudo
   ```

3. **Add your user to the sudo group**
   
   ```bash
   usermod -aG sudo [USER]
   ```

4. **Edit the sudoers configuration**
   
   ```bash
   sudo visudo
   ```

5. **Add the following configuration**
   
   ```bash
   # Set timestamp timeout (minutes)
   Defaults        timestamp_timeout=120

   # User privilege specification
   [USER]    ALL=(ALL:ALL) ALL
   ```

6. **Test changes**
   
   Log out and back in to apply changes, then test:
   
   ```bash
   sudo apt update
   ```

---

## SSH Configuration

### Initial Setup

Ensure SSH is enabled. On Raspberry Pi, this is under **Preferences** → **Raspberry Pi Configuration**.

### Firewall Rules

Tighten firewall rules to restrict SSH access to known subnets.

```bash
# Allow SSH from LAN subnets
sudo ufw allow from 192.168.1.0/24 to any port 22 proto tcp

# Allow SSH from VPN subnets
sudo ufw allow from 10.x.x.x/24 to any port 22 proto tcp
```

### SSH Key Authentication

Using SSH keys is more secure than password-based login.

1. **Client Configuration**
   
   Edit the SSH config file (e.g., `~/.ssh/config` or `C:\Users\[USER]\.ssh\config`).
   
   ```ssh
   Host [HOST-NAME]
     HostName [HOST-IP]
     User [USER]
     IdentityFile [SSH-KEY-PATH]
     ServerAliveInterval 60
     ServerAliveCountMax 5
   ```

2. **Generate SSH Key**
   
   > [!NOTE]
   > For extra security, set a passphrase when generating keys. This can be added to the client's SSH agent to avoid repeated prompts.

   ```bash
   ssh-keygen -t ed25519 -f [SSH-KEY-PATH]
   ```

3. **Host Setup**
   
   ```bash
   mkdir -p /home/[USER]/.ssh
   chmod 700 /home/[USER]/.ssh
   chown -R [USER]:[USER] /home/[USER]/.ssh
   ```

4. **Copy Public Key**
   
   From the client machine (Windows example):
   
   ```bash
   type [SSH-KEY-PATH].pub | ssh [USER]@[HOST-IP] "cat > /home/[USER]/.ssh/authorized_keys"
   ```

   > [!TIP]
   > If SSH keys fail to work despite being copied, verify the key on the host:
   > 
   > ```bash
   > ssh-keygen -l -f /home/[USER]/.ssh/authorized_keys
   > ```
   > 
   > If an error occurs, recreate the file on the host as formatting issues during transfer are common.

5. **Set Permissions**
   
   ```bash
   chmod 600 /home/[USER]/.ssh/authorized_keys
   ```

### SSH Agent (Windows)

To persist the key across restarts, add it to the SSH agent (Run as Administrator):

```powershell
Set-Service -Name ssh-agent -StartupType Automatic
Start-Service ssh-agent
ssh-add [SSH-KEY-PATH]
```

---

## Security & Maintenance

### Automatic Updates

Configure `unattended-upgrades` to handle security updates automatically.

```bash
sudo apt install unattended-upgrades
sudo dpkg-reconfigure -plow unattended-upgrades
```

### Uncomplicated Firewall (UFW)

Install and enable the firewall:

```bash
sudo apt install ufw
sudo ufw enable
```

> [!TIP]
> Use `gufw` for a graphical interface on Desktop environments: `sudo apt install gufw`.

---

## Antivirus (ClamAV)

### Installation

```bash
sudo apt update
sudo apt install clamav clamav-freshclam
```

### Configuration

1. **Setup logs and permissions**
   
   ```bash
   sudo mkdir -p /var/log/clamav
   sudo chown clamav:clamav /var/log/clamav
   ```

2. **Manage the update daemon**
   
   ```bash
   sudo systemctl stop clamav-freshclam
   sudo systemctl disable clamav-freshclam
   sudo freshclam
   ```

3. **Verify installation**
   
   ```bash
   clamscan --version
   sudo clamscan -r -i /home/[USER] --log=/var/log/clamav/scan.log
   ```

### Automated Scanning

Set up a cron job for periodic updates and scans:

```bash
sudo crontab -e
```

Add the following line:

```cron
0 4 */3 * * /usr/bin/freshclam --log=/var/log/clamav/freshclam.log && nice -n 10 ionice -c3 /usr/bin/clamscan -r -i /home /root /srv /tmp /var/tmp --log=/var/log/clamav/scan.log
```

> [!TIP]
> Periodically check the scan log at `/var/log/clamav/scan.log`

---

## Utilities & GUI (Optional)

### Pi-Apps

A visual app manager for Raspberry Pi OS:

```bash
wget -qO- https://raw.githubusercontent.com/Botspot/pi-apps/master/install | bash
```

### Graphical Interface

Install a lightweight desktop on a server to be used on demand.

```bash
sudo apt install xfce4 xfce4-goodies xorg
# Start session
startx
```

### GNOME System Monitor

```bash
sudo apt install gnome-system-monitor
```

---

## Remote Access (Optional)

### VNC Setup

Enable via **Preferences** → **Raspberry Pi Configuration**. Ensure firewall rules are updated.

### AnyDesk

> [!TIP]
> AnyDesk serves as a reliable backup if SSH or VNC access is lost.

> [!WARNING]
> On Raspberry Pi, switch away from Wayland for AnyDesk compatibility.
> 
> 1. Run `sudo raspi-config`.
> 2. Navigate to **Boot Options** → **Desktop / CLI** and select **Desktop** (not Wayland).
> 3. Reboot.

> [!TIP]
> Set up a password for unattended access in AnyDesk.

---

## System Resilience

### Hardware & Software Watchdogs

> [!INFO]
> Raspberry Pi has hardware watchdog support. For other devices, consider smart plugs for remote hard resets.

Configure watchdog settings in `/etc/systemd/system.conf`:

```ini
# Hardware watchdog timeout
RuntimeWatchdogSec=10s
# Keep active during shutdown to detect hangs
RuntimeWatchdogPreSec=10min 
```

Apply changes:

```bash
sudo systemctl daemon-reexec
```

### User Session Locking

For security on desktop sessions, implement screen locking.

1. **Official Implementation**: Enable **Desktop Auto Login** and **Screen Blanking** in Raspberry Pi Configuration.
2. **Timeout Settings**
   
   ```bash
   xset s 3600
   xset dpms 3600 3600 3600
   ```

> [!IMPORTANT]
> If official locking is unreliable, use a scheduled task (cron) to force lock the session.

Example cron job for locking:

```cron
*/30 * * * * DISPLAY=:0 XAUTHORITY=/home/[USER]/.Xauthority "/home/[USER]/scripts/screen_off.sh" >> /home/[USER]/logs/screen_cron.log 2>&1
```
