# WebDAV Setup

> [!NOTE]
> **Tags:** #WebDAV #FileSharing #Storage #Docker #Fail2Ban

## 1. Description

A protocol for secure remote file access and management over HTTP, suitable for mounting remote storage as local drives.

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

## 6. Security Recommendations

> [!NOTE]
> These recommendations assume remote access without a VPN.

### Brute-force Protection

Ensure brute-force protection is active via Fail2Ban or a Caddy plugin.

```bash
# Example Fail2Ban jail for Caddy WebDAV
[caddy-auth]
enabled = true
port    = http,https
filter  = caddy-auth
logpath = /var/log/caddy/access.log
maxretry = 5
```

Verify that unauthorised attempts are being caught by monitoring the logs:

```bash
tail -f /var/log/caddy/access.log | grep "401"
```

### Geo-blocking

Consider implementing geo-blocking to drop traffic from high-risk regions.

```bash
# In Caddyfile (utilising maxmind-geolocation)
@geoblock {
    not maxmind_geolocation {
        country_code UK EU
    }
}
handle @geoblock {
    abort
}
```

### Additional Security Tips

- **Obscurity:** Use an obscure subdomain name to avoid automated scanners (e.g., `s7orag3-media.homelab.local` instead of `dav.homelab.local`).
- **Access Control:** Point WebDAV only at specific media directories for public access. Keep the root directory accessible only via SMB and VPN.
- **VPN Integration:** For the best balance of security and convenience, utilise split-tunnelling on your VPN so WebDAV traffic is always protected without manual toggling.

## 7. Known Issues

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
