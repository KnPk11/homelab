# Caddy Deployment Notes

The primary proxy configuration for the node.

Network topology (backend node IPs and trusted LAN CIDRs) is **hardcoded in the tracked `Caddyfile`** — same approach as the UFW scripts. Secrets and host-specific values (`DOMAIN_NAME`, auth hashes, IPv6 prefix) stay under **`/srv/caddy/`** so the GitOps clone stays disposable.

### Layout

| Path | Role |
| :--- | :--- |
| `.../caddy/Caddyfile` | Tracked config (backend IPs inline; secrets via `{$VAR}`) |
| `.../caddy/Caddyfile.env.example` | Secrets template only |
| `/srv/caddy/caddy.env` | Real secrets (not in clone) |
| `/srv/caddy/Caddyfile.experimental` | Local/experimental sites (not in clone) |
| `/srv/caddy/Caddyfile` | Symlink → tracked Caddyfile |

### Secrets (`/srv/caddy/caddy.env`)

| Variable | Purpose |
| :--- | :--- |
| `DOMAIN_NAME` | Public base domain for site blocks |
| `GLANCES_HASH` | Basic-auth hash for glances |
| `WUD_HASH` | Basic-auth hash for WUD |
| `IPV6_PREFIX` | Trusted IPv6 prefix in private-only matchers |

### Deployment Strategy

1. **Clone the repository** to `/opt/homelab-repo` on the node.
2. **Create the secrets file** under the service directory:
   ```bash
   sudo mkdir -p /srv/caddy
   sudo cp /opt/homelab-repo/nodes/reverse-proxy/services/caddy/Caddyfile.env.example /srv/caddy/caddy.env
   sudo chmod 600 /srv/caddy/caddy.env
   # edit /srv/caddy/caddy.env with real DOMAIN_NAME, hashes, IPV6_PREFIX
   ```
   (If you still keep an encrypted `caddy.env` in-repo during migration, decrypt into `/srv/caddy/caddy.env` instead — strip any leftover IP keys; they are no longer read.)
3. **Experimental config** (optional) — keep only under `/srv/caddy/`:
   ```bash
   sudo touch /srv/caddy/Caddyfile.experimental
   ```
4. **Inject secrets into systemd** (network IPs are not env vars anymore):
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

To change backend node IPs, edit the literals in `Caddyfile` and reload/restart Caddy. To change domain/hashes/IPv6 prefix, edit `/srv/caddy/caddy.env` and restart Caddy.
