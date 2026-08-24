# WebDAV Setup

> [!NOTE]
> **Tags:** #WebDAV #FileSharing #Media #Storage #Docker #Symfonium
> **Service:** `media-webdav` | **Port:** `8084` (internal) -> Caddy Reverse Proxy

## 1. Overview

A lightweight, high-performance WebDAV server powered by [`hacdias/webdav`](https://github.com/hacdias/webdav). It exposes your NAS media storage (`/mnt/nas/Media`) over HTTPS for:
* **Symfonium** (Android media streaming)
* **Android File Managers** (Solid Explorer, Mixplorer)
* **Windows Network Drive Mapping**
* **Remote Clients & rclone**

---

## 2. Server Configuration (`docker-services`)

Runtime configuration is stored on `docker-services` under `/srv/webdav/config.yaml`.

### 1. Create directory & config
```bash
sudo mkdir -p /srv/webdav
sudo chmod 755 /srv/webdav
```

### 2. Configure `/srv/webdav/config.yaml`
```yaml
address: 0.0.0.0
port: 80
auth: true
behind_proxy: true
prefix: /
users:
  - username: K
    password: "YOUR_PASSWORD_OR_BCRYPT_HASH"
    scope: /data
    modify: true
    rules: []
```

> [!TIP]
> **Password format:** You can enter plain-text passwords or standard bcrypt hashes (e.g. `$2a$10$...`).

---

## 3. Client Connection Guide

### 📱 Symfonium (Android)
1. Open Symfonium → **Settings** → **Media providers** → **Add provider** → **WebDAV**.
2. **Server address:** `https://my-media.[DOMAIN]` (or local `http://192.168.50.95:8084`).
3. **Username:** `K`
4. **Password:** Your configured password.

---

### 💻 Windows Network Drive (Native Explorer)
Because Caddy terminates valid Let's Encrypt TLS on port 443, Windows maps the drive natively without extra tools:

1. Open **File Explorer** → This PC → **Map network drive**.
2. **Drive:** `Z:` (or preferred letter).
3. **Folder:** `https://my-media.[DOMAIN]`
4. Check **"Connect using different credentials"** and click **Finish**.
5. Enter username `K` and your password.

---

### 🔄 rclone / Scripted Mount
```bash
# rclone config entry
[my-media]
type = webdav
url = https://my-media.[DOMAIN]
vendor = other
user = K
pass = <obscured_password>
```

Mount as a local drive:
```bash
rclone mount my-media: /path/to/mount --vfs-cache-mode writes
```
