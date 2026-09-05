# Gatus Deployment Notes

Network topology (node IPs) is defined inline in `deploy_gatus.sh` — same approach as the UFW scripts. Secrets (`DOMAIN_NAME`, Homelab Watch token) live under **`/srv/gatus/`** so the GitOps clone stays disposable. The config template and deploy script stay in the repo; rendered config goes to `/srv/gatus/config.yaml`.

### Layout

| Path | Role |
| :--- | :--- |
| `.../gatus/config.yaml` | Tracked template (`$DOMAIN_NAME`, `$DNS_NODE_IP`, etc.) |
| `.../gatus/deploy_gatus.sh` | Inline network vars; sources secrets; renders config + restarts |
| `.../gatus/gatus.env.example` | Secrets template (`DOMAIN_NAME`, optional Telegram) |
| `/srv/gatus/gatus.env` | Real secrets (not in clone) |
| `/srv/gatus/config.yaml` | Rendered runtime config |

### Deployment Strategy

1. **Clone the repository** to `/opt/homelab-repo`.
2. **Create the secrets file**:
   ```bash
   sudo mkdir -p /srv/gatus
   sudo cp /opt/homelab-repo/nodes/reverse-proxy/services/gatus/gatus.env.example /srv/gatus/gatus.env
   sudo chmod 600 /srv/gatus/gatus.env
   # edit /srv/gatus/gatus.env with DOMAIN_NAME
   # Telegram: TELEGRAM_BOT_TOKEN / TELEGRAM_CHAT_ID
   # (same values as /etc/ssh/telegram.env)
   ```
3. **Run the deploy script**:
   ```bash
   sudo /opt/homelab-repo/nodes/reverse-proxy/services/gatus/deploy_gatus.sh
   ```

   This will:
   - Source `/srv/gatus/gatus.env` for secrets
   - Inject inline node IPs + secrets into `config.yaml` via `envsubst`
   - Write `/srv/gatus/config.yaml` and restart `gatus`

To change monitored node IPs, edit the topology block at the top of `deploy_gatus.sh` and re-run the script.

> [!NOTE]
> Do **not** symlink the template into `/srv/gatus/`. Always use `deploy_gatus.sh` after template or secret changes so `envsubst` injects values.

Telegram: custom `sendMessage`. `default-alert` sets thresholds; every endpoint still needs `alerts: *homelab-watch` (`type: custom`) or Gatus never pages. One line: `📡 Filebrowser down` / `📡 Filebrowser up`. Infra ICMP will overlap Pulse when a host dies — revisit later. Rendered `/srv/gatus/config.yaml` contains the token — mode `600`.
