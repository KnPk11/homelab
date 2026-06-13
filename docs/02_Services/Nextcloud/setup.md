# Nextcloud Setup

> [!NOTE]
> **Tags:** #Nextcloud #Cloud #Productivity #Files #Collaboration #DockerCompose

## 1. Basic Configuration

After deploying the container, utilise the following commands to update the system configuration.

### 1.1. System Values

Log into the Nextcloud container to execute these commands:

```bash
docker exec --user www-data -it nextcloud bash
```

Update the standard values:

```bash
php occ config:system:set htaccess.RewriteBase --value="/"
php occ config:system:set overwrite.cli.url --value="https://nextcloud.homelab.local"
php occ config:system:set overwritewebroot --value="/"
php occ config:system:set overwriteprotocol --value="https"
php occ config:system:set overwritehost --value="nextcloud.homelab.local"
php occ config:system:set backgroundjobs_mode --value="cron"
php occ config:system:set maintenance_window_start --value=3 --type=integer
```

### 1.2. Trusted Domains

```bash
php occ config:system:set trusted_domains 0 --value="localhost"
php occ config:system:set trusted_domains 1 --value="[HOST-IP]"
php occ config:system:set trusted_domains 2 --value="nextcloud.homelab.local"
```

### 1.3. Trusted Proxies and Headers

```bash
php occ config:system:set trusted_proxies 0 --value="[DOCKER-NETWORK]"
php occ config:system:set forwarded_for_headers 0 --value="HTTP_X_FORWARDED_FOR"
```

> [!TIP] Editing config.php directly
> If you need to edit the configuration file manually:
> 
> ```bash
> docker exec -it nextcloud bash
> apt update && apt install nano
> nano /var/www/html/config/config.php
> ```

## 2. File and Directory Permissions

### 2.1. Read-Only Configuration

If bind-mounting `config.php` in read-only mode, ensure the following is set to avoid cron errors:

```php
'config_is_read_only' => true,
```

### 2.2. Permissions

Ensure correct ownership and permissions for the configuration directory:

```bash
sudo chown 33:33 /srv/nextcloud/config
sudo chmod 660 /srv/nextcloud/config/config.php
```

### 2.3. ACL for Data Directories

To resolve permission issues on directories and files Nextcloud accesses:

```bash
# Navigate to the data directory
cd /mnt/pool

# 1. Apply to existing files
sudo setfacl -R -m u:1000:rwX,u:33:rwX Downloads Media Private Shared Shared_enc

# 2. Apply defaults for future files
sudo setfacl -Rd -m u:1000:rwX,u:33:rwX Downloads Media Private Shared Shared_enc
```

## 3. Network and Security

### 3.1. Client IP Forwarding (Apache)

To ensure client IPs are properly forwarded, edit `apache2.conf`:

```bash
sudo nano /srv/nextcloud/config/apache2.conf
```

Add the following block at the end of the file:

```apache
# Properly forward client IPs
<IfModule mod_remoteip.c>
    RemoteIPHeader X-Forwarded-For
    # Trust the specific Docker network where the reverse proxy resides
    RemoteIPInternalProxy [DOCKER-NETWORK]
</IfModule>
```

### 3.2. Rate Limiting

Navigate to **Administration settings** -> **Security** -> **Brute-force IP whitelist** and add the local network to enable rate-limiting for external IPs:
- IP Range: `[LAN-NETWORK]`

### 3.3. Security Recommendations

- Monitor security messages in the admin panel.
- Utilise the [Nextcloud Security Scanner](https://scan.nextcloud.com/) for `https://nextcloud.homelab.local`.
- Verify that the reverse proxy is correctly passing real client IPs.
- Review the **Deleted files** section periodically.

## 4. Maintenance and Upgrades

### 4.1. Background Jobs

Go to **Basic settings** -> **Background jobs** and select **Cron (recommended)**.

### 4.2. Upgrading Nextcloud

1. Update the image version in the Docker Compose file.

2. Perform the database migration:

```bash
docker exec --user www-data -it nextcloud php occ upgrade
```

3. Optimise performance after the upgrade:

```bash
docker exec --user www-data -it nextcloud sh
php occ maintenance:repair --include-expensive
php occ db:add-missing-indices
php occ db:add-missing-primary-keys
```

## 5. Nextcloud Talk (High Performance Backend)

### 5.1. Installation

Install the Talk app via the Nextcloud app marketplace.

### 5.2. High Performance Backend (HPB) Setup

> [!NOTE]
> This is needed for scalable video call hosting.
> Guides [here](https://github.com/nextcloud-snap/nextcloud-snap/wiki/How-to-configure-talk-HPB-with-Docker) and [here](https://arnowelzel.de/en/nextcloud-talk-high-performance-backend-with-docker)

Generate secrets for the service (run three times):

```bash
openssl rand -hex 16
```

Configure HPB in Nextcloud:

```bash
docker exec --user www-data -it nextcloud sh
php occ config:system:set talk.signaling_url --value="http://nextcloud_talk_hpb:8081"
php occ config:system:set talk.signaling_host --value="talk-hpb.homelab.local"
```

Add a rule for Caddy:

```ini
talk-hpb.local.com {
    import ...

    reverse_proxy nextcloud_talk_hpb:8081 {
        # Helper to ensure Nextcloud sees the correct headers
        header_up X-Real-IP {remote_host}
        header_up X-Forwarded-For {remote_host}
        header_up X-Forwarded-Proto https
    }
}
```
### 5.3. Configuration

Configure the settings in the Nextcloud UI (Account icon -> **Administration settings** -> **Talk**):

- **High-performance backend**:
  - URL: `https://talk-hpb.homelab.local`
  - Shared secret: `[SECRET]` (Signalling secret used in Docker Compose)
- **STUN servers**:
  - Add `talk-hpb.homelab.local:3478`
- **TURN servers**:
  - Type: `turn:only`
  - TURN server URL: `talk-hpb.homelab.local:3478`
  - TURN server secret: `[SECRET]` (TURN secret used in Docker Compose)

### 5.4. Network Configuration

- Forward port `3478` (TCP/UDP) on the router.
- Do NOT set the subdomain to LAN-only in the reverse proxy, as this prevents external calls.

## 6. Other Options

### 6.1. File Encryption (Server-Side)

Nextcloud's Server Side Encryption can be set up on a separate directory or storage.

> [!NOTE] Sharing encrypted files
> Creating a separate user is preferred and more secure than utilizing public links.

> [!WARNING] File manipulations
> Encrypted files will break if file operations are performed outside of Nextcloud (e.g., moving files to a different directory).

## 7. Known Issues and Troubleshooting

### 7.1. User ID Settings in Docker

PUID and PGID environment variables do not take effect as the image is designed to run as `www-data`.

### 7.2. Android Authentication

Authentication issues on Android may relate to incorrect trusted proxy setups or require adding the device as a trusted device in admin settings.

### 7.3. HPB Secrets

> [!FAILURE] Secrets handling
> The image does not support `_FILE` directives. A custom entrypoint may also break logging.
> 
> ```yaml
> entrypoint:
>   - /bin/sh
>   - -c
>   - |
>     export SIGNALING_SECRET="$(cat /run/secrets/nextcloud_signalling_secret)"
>     export TURN_SECRET="$(cat /run/secrets/nextcloud_turn_secret)"
>     export INTERNAL_SECRET="$(cat /run/secrets/nextcloud_internal_secret)"
> 
>     exec /start.sh "$@"
> ```
> 
> To hide plaintext secrets, mount the `.env` file into the Portainer filesystem and use the `env_file` directive for HPB in Docker Compose. Remove these variables from the `environment` section entirely.

### 7.4. Connectivity Issues

If Nextcloud reports security warnings or internet connectivity issues, consider adding a specific trusted proxy or extra hosts to the Docker Compose file:

```yaml
services:
  nextcloud:
    dns:
      - 8.8.8.8
      - 1.1.1.1
    extra_hosts:
      - "nextcloud.homelab.local:host-gateway"
```

```bash
php occ config:system:set trusted_proxies 2 --value="[PROXY-IP]"
```
