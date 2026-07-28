# WebDAV Setup

> [!NOTE]
> #WebDAV #FileSharing #Storage #Docker #Fail2Ban

## 1. Description

A protocol for secure remote file access and management over HTTP, suitable for mounting remote storage as local drives.

Brute-force, geo-blocking, and exposure tips: [security.md](security.md).

## 2. Directory Preparation

Create the necessary configuration directories and set appropriate permissions:

```bash
sudo mkdir -p /srv/webdav/config
sudo chmod -R 755 /srv/webdav/config
```

## 3. Entrypoint Configuration

This Docker image is not persistent and does not support file injections. As a workaround, create and mount an entrypoint script that reads secrets:

```bash
#!/bin/sh
set -e

export APP_USER_NAME=[USER]
export APP_USER_PASSWD=$(cat /run/secrets/[SECRET])

exec "$WEBDAV_SOURCE_DIR/entrypoint.sh"
```

Ensure the script is executable:

```bash
chmod +x /srv/webdav/entrypoint.sh
```

## 4. Deployment Options

### Port-forwarded Setup

1. Forward the relevant ports if utilising port forwarding.
2. Mount on Windows using `https://webdav.homelab.local:8443/data/`

### Reverse-proxied Setup

1. Remove certificates, TLS, and port mappings from the `docker-compose.yml` file if utilising Caddy.
2. Configure the `SERVER_NAME` environment variable.

## 5. Multi-user Support

1. Duplicate the Docker Compose configuration and enable the `URL_PREFIX` variable to create unique subpaths:

   ```yaml
        - URL_PREFIX=/webdav_shared
      volumes:
        - /mnt/pool/Shared:/var/webdav/data
   ```

2. Alternatively, run at the root path and create additional subdomains.

## 6. Known Issues

> [!WARNING]
> **Mounting as a drive on Windows**
>
> Native Windows drive mounting often fails, similar to issues seen with Nextcloud.
>
> Possible solutions include:
> - Utilising a custom WebDAV plugin for Caddy.
> - Using third-party WebDAV mounters such as `rclone`.

### rclone Workaround

1. Add the address with credentials: `https://webdav.homelab.local/data/`
2. Mount the drive by executing:

   ```cmd
   ./rclone mount webdav: Y: --vfs-cache-mode writes --links
   ```
