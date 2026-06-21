# Caddy Deployment Notes

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
4. **Inject Environment Variables into Systemd**:
   Create an override file so Caddy knows to load the `.env` file upon startup:
   ```bash
   sudo mkdir -p /etc/systemd/system/caddy.service.d/
   echo "[Service]" | sudo tee /etc/systemd/system/caddy.service.d/override.conf
   echo "EnvironmentFile=/opt/homelab-repo/nodes/caddy-101/services/Caddy/.env" | sudo tee -a /etc/systemd/system/caddy.service.d/override.conf
   ```
5. **Symlink the Configuration**:
   Symlink the repository's Caddyfile over the default system Caddyfile. Don't forget to symlink the experimental file too so the import directive finds it!
   ```bash
   sudo rm /srv/caddy/Caddyfile
   sudo ln -s /opt/homelab-repo/nodes/caddy-101/services/Caddy/Caddyfile /srv/caddy/Caddyfile
   sudo ln -s /opt/homelab-repo/nodes/caddy-101/services/Caddy/Caddyfile.experimental /srv/caddy/Caddyfile.experimental
   ```
6. **Apply Configuration**:
   Reload the systemd daemon to pick up the override, then restart Caddy:
   ```bash
   sudo systemctl daemon-reload
   sudo systemctl restart caddy
   ```
