# Caddy Deployment Notes

The primary proxy configuration for the node.

Runtime files live under `/srv/caddy/`. The GitOps clone only holds tracked config and examples — real secrets stay outside the repo so the clone stays disposable.

### Layout

| Path | Role |
| :--- | :--- |
| `/opt/homelab-repo/.../Caddy/Caddyfile` | Tracked config (symlinked into `/srv/caddy/`) |
| `/opt/homelab-repo/.../Caddy/Caddyfile.env.example` | Template only |
| `/srv/caddy/caddy.env` | Real secrets (not in clone; same `*.env` naming as other services) |
| `/srv/caddy/Caddyfile.experimental` | Local/experimental sites (not in clone) |
| `/srv/caddy/Caddyfile` | Symlink → tracked Caddyfile |

### Deployment Strategy

1. **Clone the repository** to `/opt/homelab-repo` on the node.
2. **Decrypt the environment file** from the repository into the service directory:
   ```bash
   sudo mkdir -p /srv/caddy
   sops -d /opt/homelab-repo/nodes/reverse-proxy/services/caddy/caddy.env > /srv/caddy/caddy.env
   sudo chmod 600 /srv/caddy/caddy.env
   ```
3. **Experimental config** (optional) — keep only under `/srv/caddy/`:
   ```bash
   sudo touch /srv/caddy/Caddyfile.experimental
   ```
4. **Inject env into systemd**:
   ```bash
   sudo mkdir -p /etc/systemd/system/caddy.service.d/
   sudo tee /etc/systemd/system/caddy.service.d/override.conf <<'EOF'
   [Service]
   EnvironmentFile=/srv/caddy/caddy.env
   EOF
   ```
5. **Symlink tracked Caddyfile only**:
   ```bash
   sudo ln -sfn /opt/homelab-repo/nodes/reverse-proxy/services/caddy/Caddyfile /srv/caddy/Caddyfile
   ```
6. **Apply**:
   ```bash
   sudo systemctl daemon-reload
   sudo systemctl restart caddy
   ```
