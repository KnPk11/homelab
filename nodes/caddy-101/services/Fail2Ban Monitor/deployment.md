# Fail2Ban Monitor Deployment Notes

Secrets live under **`/srv/fail2ban-monitor/`** so the GitOps clone stays disposable. Templates and the deploy script stay in the repo.

### Layout

| Path | Role |
| :--- | :--- |
| `.../Fail2Ban Monitor/jail.local` | Tracked template (`$HOMELAB_SUBNETS`, etc.) |
| `.../Fail2Ban Monitor/fail2ban.env.example` | Template only |
| `.../Fail2Ban Monitor/deploy_fail2ban.sh` | Renders jail + symlinks + restarts |
| `/srv/fail2ban-monitor/fail2ban.env` | Real secrets (not in clone) |
| `/srv/fail2ban-monitor/fail2ban_bans.py` | Symlink → tracked script in clone |

### Deployment Strategy

1. **Clone the repository** to `/opt/homelab-repo`.
2. **Create the environment file** under the service directory:
   ```bash
   sudo mkdir -p /srv/fail2ban-monitor
   sudo cp "/opt/homelab-repo/nodes/caddy-101/services/Fail2Ban Monitor/fail2ban.env.example" \
     /srv/fail2ban-monitor/fail2ban.env
   sudo chmod 600 /srv/fail2ban-monitor/fail2ban.env
   # edit /srv/fail2ban-monitor/fail2ban.env (e.g. HOMELAB_SUBNETS)
   ```
3. **Run the deploy script**:
   ```bash
   sudo "/opt/homelab-repo/nodes/caddy-101/services/Fail2Ban Monitor/deploy_fail2ban.sh"
   ```

   This will:
   - Render `jail.local` with `envsubst` into `/etc/fail2ban/jail.local`
   - Symlink `crowdsec_action.conf` and `fail2ban_bans.py`
   - Restart `fail2ban` and `fail2ban-monitor`
