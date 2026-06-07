# Cockpit

> [!NOTE]
> **Tags:** #cockpit #server_management #linux #web_ui

## 1. Installation

Run these three commands:

```bash
sudo apt update
sudo apt install cockpit -y
sudo systemctl enable --now cockpit.socket # Ensures it starts automatically on reboot
```

Add a UFW rule if needed:

```bash
sudo ufw allow 9090/tcp
```

## 2. Initial Access

- Navigate to `https://[IP]:9090`
- Login with **non-root** Debian credentials

> [!TIP]
> **Full Access**: Toggle off **Limited Access** in the top-right for full control.

## 3. Reverse Proxy Setup

Find Docker gateway:

```bash
ip addr show docker0 | grep -Po 'inet \K[\d.]+'
```

Configure Cockpit socket:

```bash
sudo nano /etc/systemd/system/cockpit.socket.d/listen.conf
```

```ini
[Socket]
ListenStream=
ListenStream=127.17.0.1:9090  # Match your docker IP
```

Update Cockpit config:

```bash
sudo nano /etc/cockpit/cockpit.conf
```

```bash
[WebService]
Origins = https://cockpit.example.com wss://cockpit.example.com https://[SERVICE-IP]:9090
ProtocolHeader = X-Forwarded-Proto
ForwardedForHeader = X-Forwarded-For
AllowUnencrypted = true
IdleTimeout = 30
```

Apply changes:

```bash
sudo systemctl restart cockpit
```

Caddy Configuration:

```bash
reverse_proxy host.docker.internal:9090  # Preferred
# reverse_proxy 172.17.0.1:9090         # Fallback
```

Check Cockpit is reachable from Caddy:

```bash
curl -I http://172.17.0.1:9090
```

In Caddyfile:

```bash
reverse_proxy host.docker.internal:9090
```

## 4. Security Enhancements

Make sure Fail2Ban is looking at the auth attempts via the custom logs in `/mnt/logs*`, or create a specific jail for Cockpit, pointing it at the system auth log:

```bash
[cockpit]
enabled = true
port = 9090
logpath = /var/log/auth.log
maxretry = 3
bantime = 3600
findtime = 600
```

## 5. Custom Plugins

### 45Drives Navigator

Run the setup script:

```bash
curl -sSL https://repo.45drives.com/setup | sudo bash
```

Update and install:

```bash
sudo apt update
sudo apt install cockpit-navigator -y
```

> [!TIP]
> **Manual Install**: If there's a compatibility issue with the latest Debian OS, run this:
> 
> Import GPG Key:
> 
> ```bash
> wget -qO - https://repo.45drives.com/key/gpg.asc | sudo gpg --dearmor -o /usr/share/keyrings/45drives-archive-keyring.gpg
> ```
> 
> Add 45drives.sources:
> 
> ```bash
> cd /etc/apt/sources.list.d
> sudo curl -sSL https://repo.45drives.com/lists/45drives.sources -o /etc/apt/sources.list.d/45drives.sources
> sudo apt update
> ```
> 
> Install the needed package:
> 
> ```bash
> sudo apt install cockpit-navigator
> ```

Refresh the Cockpit browser tab. On the left-hand menu you will now see a new item called **Navigator**.

### SMB Client

Install by running:

```bash
sudo apt install cockpit-file-sharing
```

Refresh the Cockpit browser tab. On the left-hand menu you will now see a new item called **File Sharing**.

> [!WARNING]
> **Post-Import**: 
> - **Do not edit `/etc/samba/smb.conf`** after initial import.
> - Avoid clicking the "Import" button again.
> 
> The contents of the `/etc/samba/smb.conf` will move to Cockpit's registry.
