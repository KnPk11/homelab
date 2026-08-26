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
prefix: /
behindProxy: true

# Global defaults
directory: /data
permissions: CRUD

users:
  - username: K
    password: "{bcrypt}$2a$10$..."  # or plain-text password
    directory: /data
    permissions: CRUD
    rules: []
```

> [!TIP]
> **Password format:** 
> * **Bcrypt:** Prefix the hash with `{bcrypt}` (e.g. `"{bcrypt}$2a$10$..."`). Generate with:
>   `docker exec media-webdav webdav bcrypt 'YOUR_PASSWORD'`
> * **Plain text:** Enter directly as `"your_password"`.


## 3. Client Connection Guide

### 1. Symfonium (Android)
1. Open Symfonium → **Settings** → **Media providers** → **Add provider** → **WebDAV**.
2. **Server address:** `https://my-media.[DOMAIN]` (or local `http://192.168.50.95:8084`).
3. **Username:** `K`
4. **Password:** Your configured password.


### 2. Windows Network Drive (Native Explorer)
Because Caddy terminates valid Let's Encrypt TLS on port 443, Windows maps the drive natively:

#### Prerequisites (WebClient Service)
Windows requires the **`WebClient`** service to be running:
1. Press `Win + R`, type `services.msc`, and press Enter.
2. Ensure **WebClient** is **Running** and set to **Automatic** (or run `net start webclient` in Administrator CMD).

#### Mapping the Drive
1. Open **File Explorer** → This PC → **Map network drive**.
2. **Drive:** `Z:` (or preferred letter).
3. **Folder:** `https://my-media.[DOMAIN]`
4. Check **"Connect using different credentials"** (and optionally "Reconnect at sign-in").
5. Click **Finish**, then authenticate with username `K` and your password.

#### Large File Tweak (Optional / Recommended for Media)
By default, Windows limits single-file WebDAV transfers to 50 MB. To lift this limit to 4 GB:
1. In Registry Editor (`regedit`), navigate to:
   `HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Services\WebClient\Parameters`
2. Set **`FileSizeLimitInBytes`** (Decimal) to **`4294967295`** (4 GB).
3. Restart the `WebClient` service or reboot.


### 3. rclone / Scripted Mount
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


## 4. Multi-User & Granular Permissions

You can serve multiple isolated users from the same single container. The `directory` parameter acts as a private `chroot` jail for each user, and `permissions` controls their access (`CRUD`, `R`, `none`):

```yaml
users:
  # 1. Admin (Full access to all media)
  - username: K
    password: "{bcrypt}$2a$10$..."
    directory: /data
    permissions: CRUD
    rules:
      - regex: '^/.*(\.git|\.DS_Store|@eaDir|Thumbs\.db).*$'
        permissions: none # Hide/block hidden system files

  # 2. Friend share (Private personal subfolder only)
  - username: user
    password: "{bcrypt}$2a$10$..."
    directory: /data/Shared/User
    permissions: CRUD
    rules: []

  # 3. Guest (Read-only shared library)
  - username: guest
    password: "{bcrypt}$2a$10$..."
    directory: /data/Shared/Guest
    permissions: R
    rules: []
```

