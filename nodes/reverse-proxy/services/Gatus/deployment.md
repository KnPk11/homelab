# Gatus Deployment Notes

Secrets live under **`/srv/gatus/`** so the GitOps clone stays disposable. The config template and deploy script stay in the repo; rendered config goes to `/opt/gatus/config.yaml`.

### Layout

| Path | Role |
| :--- | :--- |
| `.../Gatus/config.yaml` | Tracked template (`$DOMAIN_NAME`, node IPs, etc.) |
| `.../Gatus/gatus.env.example` | Template only |
| `.../Gatus/deploy_gatus.sh` | Renders config + restarts service |
| `/srv/gatus/gatus.env` | Real values (not in clone) |
| `/opt/gatus/config.yaml` | Rendered runtime config |

### Deployment Strategy

1. **Clone the repository** to `/opt/homelab-repo`.
2. **Create the environment file** under the service directory:
   ```bash
   sudo mkdir -p /srv/gatus
   sudo cp /opt/homelab-repo/nodes/reverse-proxy/services/Gatus/gatus.env.example /srv/gatus/gatus.env
   sudo chmod 600 /srv/gatus/gatus.env
   # edit /srv/gatus/gatus.env with domain + node IPs
   ```
3. **Run the deploy script**:
   ```bash
   sudo /opt/homelab-repo/nodes/reverse-proxy/services/Gatus/deploy_gatus.sh
   ```

> [!NOTE]
> Do **not** symlink the template into `/opt/gatus/`. Always use `deploy_gatus.sh` after template or secret changes so `envsubst` injects values securely.
