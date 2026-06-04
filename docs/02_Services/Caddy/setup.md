# Caddy Installation & Configuration

> [!NOTE]
> **Tags:** #Caddy #Networking #Proxy #Docker #Native

## Overview
This guide covers both Docker and bare-metal installation methods for the Caddy reverse proxy.

---
## Option A: Docker Setup

### 1. Create Network
```bash
docker network create caddy_shared
```

### 2. Create Directories
```bash
sudo mkdir -p /srv/caddy/
```

### 3. Open Firewall Ports
```bash
sudo ufw allow 80/tcp 
sudo ufw allow 443/tcp
```
Caddy automatically fetches certificates from Let's Encrypt.

### 4. Set Log Permissions
```bash
sudo chmod -R 777 /mnt/logs/caddy
```

> [!NOTE]
> **Configuration Location**
> 
> The configuration can be found in the following location:
> `/srv/caddy/etc-caddy/Caddyfile`

---
## Option B: Bare-Metal LXC Setup

### 1. Install Build Dependencies
```bash
apt update && apt install -y debian-keyring debian-archive-keyring apt-transport-https \
curl build-essential golang-go
```

### 2. Install `xcaddy` & Build Binary
```bash
# Download and install xcaddy
curl -L "https://github.com/caddyserver/xcaddy/releases/download/v0.4.2/xcaddy_0.4.2_linux_amd64.tar.gz" | tar -xz
mv xcaddy /usr/bin/

# Build your custom Caddy with plugins
xcaddy build \
    --with github.com/caddyserver/transform-encoder \
    --with github.com/mholt/caddy-ratelimit

# Move the binary to the standard system path
mv caddy /usr/bin/
```

### 3. Create the Caddy System User
> [!TIP]
> **Security Practice**: Running a web server as root, even in an unprivileged container, is poor security practice.

```bash
groupadd --system caddy
useradd --system \
    --gid caddy \
    --create-home \
    --home-dir /var/lib/caddy \
    --shell /usr/sbin/nologin \
    --comment "Caddy web server" \
    caddy
```

### 4. Initialise Directories
```bash
# Give the caddy user ownership of the config and data directories
chown -R caddy:caddy /srv/caddy
chown -R caddy:caddy /var/lib/caddy

# Create log directory
mkdir -p /var/log/caddy
chown -R caddy:caddy /var/log/caddy
```

### 5. Create the Service File
Create `/etc/systemd/system/caddy.service`:

```ini
[Unit]
Description=Caddy
Documentation=https://caddyserver.com/docs/
After=network.target network-online.target
Requires=network-online.target

[Service]
Type=notify
User=caddy
Group=caddy
ExecStart=/usr/bin/caddy run --environ --config /srv/caddy/Caddyfile
ExecReload=/usr/bin/caddy reload --config /srv/caddy/Caddyfile --force
TimeoutStopSec=5s
LimitNOFILE=1048576
LimitNPROC=512
PrivateTmp=true
ProtectSystem=full
AmbientCapabilities=CAP_NET_BIND_SERVICE

[Install]
WantedBy=multi-user.target
```

### 6. Enable and Start the Service
```bash
systemctl daemon-reload
systemctl enable caddy
systemctl start caddy
```

### 7. Fix Log Permissions (if needed)
```bash
mkdir -p /var/log/caddy/plaintext/
chown -R caddy:caddy /var/log/caddy/
chmod -R 775 /var/log/caddy/
```

### 8. Verify
```bash
systemctl status caddy
```

---
## Common Configuration

### Networking & Firewall
> [!NOTE]
> **Static DNS**: Ensure you set a **Static DNS** for this container in Proxmox.

#### Proxmox Firewall
1. Enable the firewall at **Datacenter** → **Firewall** → **Options**.
2. Set **Input policy** to `DROP`.

> [!TIP]
> **Proxmox Firewall Script**: Run `proxmox_firewall.sh` to secure the node. Consider using VLANs to isolate Caddy and public-facing VMs from the main homelab LAN.

### Separation of Logs
It is best to separate "disposable" container logic from valuable logs, which need to be retained over a long period.

**Solution:** Create a dedicated 10GB mount point on `local-lvm` attached directly to the Caddy LXC.

| Item           | Detail                                        |
| -------------- | --------------------------------------------- |
| Storage        | `local-lvm:10` → `mp0` → `/mnt/logs`          |
| Caddy UID:GID  | `999:991` (unprivileged remap)                |
| Services       | Caddy, Fail2Ban, CrowdSec, Rsyslog (MikroTik) |
| Windows Access | SMB share at `\\[CADDY-IP]\logs`              |

While possible to store logs on a NAS, it is not recommended as the NAS is a separate system; if the NAS is down, the reverse proxy might lock up if it cannot commit logs.

**Key Commands:**
```bash
# Attach disk to LXC from Proxmox host
pct set [LXC-ID] -mp0 local-lvm:10,mp=/mnt/logs

# Fix permissions inside unprivileged container
chown -R 999:991 /mnt/logs/current/caddy
chmod -R 755 /mnt/logs
```

### Log Rotation
> [!TIP]
> **Log Processing**: Use the `process_logs.sh` script to automatically move rotated Caddy logs and rotate large syslogs. It also creates a snapshot of currently active logs. It is recommended to schedule this to run daily via cron.
