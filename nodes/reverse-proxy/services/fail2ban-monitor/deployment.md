# Fail2Ban Monitor Deployment Notes

Templates and the deploy script stay in the repo. Network topology (ignoreip subnets) is defined inline in `deploy_fail2ban.sh` — same approach as the UFW scripts. The monitor binary is symlinked under **`/srv/fail2ban-monitor/`**.

### Layout

| Path | Role |
| :--- | :--- |
| `.../fail2ban-monitor/jail.local` | Tracked template (`$HOMELAB_SUBNETS`) |
| `.../fail2ban-monitor/deploy_fail2ban.sh` | Inline network vars, renders jail + symlinks + restarts |
| `.../fail2ban-monitor/crowdsec_action.conf` | Fail2Ban → CrowdSec action |
| `.../fail2ban-monitor/fail2ban_bans.py` | Ban dashboard script |
| `/srv/fail2ban-monitor/fail2ban_bans.py` | Symlink → tracked script in clone |
| `/srv/fail2ban-monitor/banned-history.jsonl` | Append-only rolling ban log (runtime, not in git) |

The widget reads **only** `banned-history.jsonl` over a rolling 24h window. Fail2Ban `actionban` appends immediately; a background thread also ingests CrowdSec via `cscli alerts list --limit 0` so CrowdSec's default 50-row cap and nightly `process_logs.sh` truncation cannot shrink the history.

### Deployment Strategy

1. **Clone the repository** to `/opt/homelab-repo`.
2. **Run the deploy script**:
   ```bash
   sudo "/opt/homelab-repo/nodes/reverse-proxy/services/fail2ban-monitor/deploy_fail2ban.sh"
   ```

   This will:
   - Render `jail.local` with `envsubst` (using `HOMELAB_SUBNETS` from the script) into `/etc/fail2ban/jail.local`
   - Symlink `crowdsec_action.conf` and `fail2ban_bans.py`
   - Restart `fail2ban` and `fail2ban-monitor`

To change trusted subnets, edit `HOMELAB_SUBNETS` at the top of `deploy_fail2ban.sh` and re-run the script.
