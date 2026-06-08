# Docker Setup

> [!NOTE]
> **Tags:** #Docker #Security #Infrastructure

## 1. General Principles
- Utilise Docker images from reputable repositories or authors.
- Spin down containers that are rarely used for better security.

## 2. Privileges

### 2.1 Rootless Docker
Run Docker under a non-root user (e.g., `[USER]`) to isolate containers from the host.
- Prevents containers from gaining real root access.
- Files in volumes are owned by your user (no `root:root` issues).
- Requires changing how Docker is run.
- Slightly less compatible with low ports and some images.

### 2.2 Container Privileges
Minimise what containers can do:
- Avoid `privileged: true` (too permissive).
- Use `user: [USER-ID]:[GROUP-ID]` to drop root inside container.
- Drop Linux capabilities with:

   ```yaml
   cap_drop:
     - ALL
   cap_add:
     - CHOWN
     - DAC_OVERRIDE
     - FOWNER
     - SETGID
     - SETUID
     - KILL
   ```

- Use `read_only: true` for containers that only serve data; it reduces a container’s blast radius if compromised.
- Mount binded volumes with `:ro` flag if the service is not meant to change and write new data.

## 3. Auditing

> [!NOTE]
> Occasionally audit the Docker setup using vulnerability scanners such as `Docker Bench`.

## 4. Secrets

> [!NOTE]
> **Docker Swarm** mode is a native and secure way to manage secrets.

### 4.1 `_FILE` Environment Variables
Store Docker Compose plaintext passwords in **secrets**, or environment files.

1. Create a file with just the password.
2. Define secret in Compose:

   ```yaml
   secrets:
     photoprism_password:
       file: /srv/secrets/photoprism_password
   ```

3. Reference it in the service:

   ```yaml
   services:
     photoprism:
       environment:
         PHOTOPRISM_ADMIN_PASSWORD_FILE: "/run/secrets/photoprism_password"
       secrets:
         - photoprism_password
   ```

4. Docker injects the secret file into `/run/secrets/`, and PhotoPrism reads the password via the `_FILE` env var.

**Advantages:**
- Keeps secrets out of `docker-compose.yml` and `.env`.
- File mounted with restrictive permissions (`0400`).
- Ideal for production or privacy-critical setups.

### 4.2 Environmental Variables
Don't bother with creating a Docker Compose secret for each changed password after the initial setup. Let Vaultwarden be the source of truth for these secrets, and only keep Docker secrets for things like:
- MariaDB root user or app user password
- SMTP passwords
- API keys

1. Create an `.env` file with the following format storing all the variables:

   ```yaml
   NEXTCLOUD_DB_PASS=[SECRET]
   NEXTCLOUD_MYSQL_ROOT_PASSWORD=[SECRET]
   OWNCLOUD_DB_PASS=[SECRET]
   ```

2. Define variables in Compose:

   ```yaml
   services:
     nextcloud:
       environment:
         - MYSQL_PASSWORD=${NEXTCLOUD_DB_PASS}

     nextcloud_db:
       environment:
         - MYSQL_ROOT_PASSWORD=${NEXTCLOUD_MYSQL_ROOT_PASSWORD}

     owncloud:
       environment:
         - MYSQL_PASSWORD=${OWNCLOUD_DB_PASS}
   ```

> [!NOTE]
> If you declare variables as they are (e.g., `MYSQL_PASSWORD`, `NEXTCLOUD_MYSQL_ROOT_PASSWORD`), Portainer might complain that the variable already exists if you have multiple services using these with different passwords.

3. Load the `.env` file into Portainer's variables section, below the stack editor.

**Notes:**
- Still insecure as Portainer will store it as plain text on its side.

**Best Practice - Permissions on the password files:**

   ```bash
   chmod 600 /srv/secrets/photoprism_password
   chown [USER-ID]:[GROUP-ID] /srv/secrets/photoprism_password
   ```

**Security Tip:** Store secrets on an **encrypted partition** to protect data at rest. Mount it at runtime with restricted access.

## 5. Resource Constraints
It is a good idea to set max resource constraints per container to prevent denial of service attacks.

   ```yaml
   deploy:
     resources:
       limits:
         cpus: '0.50'
         memory: 50M
         pids: 1
       reservations:
         cpus: '0.25'
         memory: 20M
   ```

## 6. Firewall
Docker [bypasses UFW rules](https://www.reddit.com/r/selfhosted/comments/1atjsra/til_docker_overrides_ufw_and_iptables_rules_by/) by default if you publish ports using `-p` or `ports:`, unless host network is used. To check:

   ```bash
   sudo iptables -L DOCKER
   sudo netstat -tuln | grep LISTEN
   sudo docker ps --format "table {{.Names}}\t{{.Ports}}"
   ```

**Solution:**
- Use `ufw-docker` to regain control.
- Use Docker’s internal bridge network and reverse proxy - prefer `expose:` over `ports:`.
- Restrict bindings to localhost or the host's internal IP:

   ```yaml
   ports:
     - "127.0.0.1:8080:80" # localhost
     - "[HOST-IP]:8080:80"
   ```

- Use rootless Docker, but not every service can run in rootless mode.

| Docker setup                             | UFW controls access? | Notes                                    |
| ---------------------------------------- | -------------------- | ---------------------------------------- |
| `ports: - "80:80"`                       | ❌ No                 | Docker opens iptables rules _before_ UFW |
| `ports: - "127.0.0.1:8080:80"`           | ✅ Yes (indirectly)   | Binds only to loopback                   |
| No published port, only Caddy forwarding | ✅ Yes                | UFW only needs to allow Caddy’s ports    |
| `network_mode: host`                     | ✅ Yes (depends)      | UFW sees it like any other host process  |

If anything binds to `0.0.0.0` or `::`, it's potentially exposed — even if UFW rules seem safe, **Docker can still bypass** UFW!

## 7. Hardening Docker
If you haven’t yet, consider adding this to `/etc/docker/daemon.json`:

   ```json
   {
     "iptables": false
   }
   ```

> [!WARNING]
> Docker will no longer manage firewall rules at all. You **must** then define `ufw` rules manually for published ports.

Make sure nothing unexpected is listening on `0.0.0.0:*` or `[::]:*`.

   ```bash
   sudo ss -tulnp
   ```

If anything unexpected is listening, restrict port binds in `docker-compose.yml`.

## 8. Updating
Use **Watchtower** to auto-update containers (carefully). To see updated containers, run:

   ```bash
   docker logs -f watchtower
   ```

## 9. Networking
- Consider network isolation per service stack. For example:

   ```yaml
   services:
     nextcloud:
       networks:
         - caddy_shared
         - nextcloud_internal

     jellyfin:
       networks:
         - caddy_shared
         - jellyfin_internal
   ```

- Avoid exposing services with host networking (exceptions include services such as SMB, Avahi, WSDD).

## 10. Binded Mounts Control
- **Granular bind mounts:** Only mount the specific subdirectory each service needs. For example:
  - `/mnt/data/nextcloud` → Nextcloud
  - `/mnt/data/jellyfin` → Jellyfin
  - `/mnt/data/photos` → PhotoPrism
  - This way, a compromise in one service doesn’t expose unrelated data.
- **Use Docker named volumes for app data:** Keep application configs and databases in named volumes, and only mount media/data directories as needed.
- **Enforce host-level ACLs:** On the host filesystem, set Unix permissions or use ACLs so that even if two containers mount the same directory, one can’t read/write what it shouldn’t.

## 11. Named Volumes
For application data, such as `nextcloud_data`, and especially databases like `nextcloud_db`, it is best to stick with **named volumes**.
- Named volumes are managed by the Docker engine itself.
- Best practice for application data because it abstracts away the host's filesystem structure.
- Makes the setup more portable - easier to back up with standard Docker tools.
- Prevents potential permission conflicts on the host.

> [!NOTE]
> Some services, like Nextcloud or Vaultwarden, have their own internal protection mechanisms, like rate limiting.
