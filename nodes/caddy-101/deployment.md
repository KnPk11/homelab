# Caddy-101 Deployment Notes

## Log Manager Script
The `process_logs.sh` script handles log rotation, archival, and retention.

### Deployment Strategy
1. **Clone the repository** to a central location on the node (e.g., `/opt/homelab-repo`).
2. **Create the Environment File**:
   Copy the example environment file and update it with local values if needed:
   ```bash
   cp /opt/homelab-repo/nodes/caddy-101/scripts/process_logs.env.example /opt/homelab-repo/nodes/caddy-101/scripts/process_logs.env
   ```
3. **Symlink to cron**:
   To run the script automatically (e.g., daily at midnight), create a symlink in the daily cron directory:
   ```bash
   sudo ln -s /opt/homelab-repo/nodes/caddy-101/scripts/process_logs.sh /etc/cron.daily/process_logs
   ```

> [!NOTE]
> The script dynamically discovers its `.env` file via `readlink`, so it can be safely symlinked anywhere on the system without breaking its configuration paths.

## Caddyfile Configuration
The primary proxy configuration for the node.

### Deployment Strategy
1. **Clone the repository** to a central location on the node (e.g., `/opt/homelab-repo`).
2. **Create the Environment File**:
   Copy the example `.env` template and update it with your actual IPs and secret hashes:
   ```bash
   cp /opt/homelab-repo/nodes/caddy-101/services/Caddy/Caddyfile.env.example /opt/homelab-repo/nodes/caddy-101/services/Caddy/.env
   ```
3. **Create the Experimental Configuration** (Optional):
   Create a local `Caddyfile.experimental` to house your uncommitted, temporary web services:
   ```bash
   touch /opt/homelab-repo/nodes/caddy-101/services/Caddy/Caddyfile.experimental
   ```
4. **Symlink the Configuration**:
   Symlink the repository's Caddyfile over the default system Caddyfile:
   ```bash
   sudo rm /srv/caddy/Caddyfile
   sudo ln -s /opt/homelab-repo/nodes/caddy-101/services/Caddy/Caddyfile /srv/caddy/Caddyfile
   ```
5. **Apply Configuration**:
   ```bash
   sudo systemctl reload caddy
   ```
