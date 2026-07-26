# CrowdSec Deployment Notes

## Configuration Templates

CrowdSec configs (e.g. `config.yaml`, bouncers) do not read a `.env` at runtime. We render them into `/etc/crowdsec/` with `envsubst` via `deploy_crowdsec.sh`.

Network topology (LAPI URL, trusted subnet, MikroTik address) is defined inline in `deploy_crowdsec.sh` — same approach as the UFW scripts. Secrets live under **`/srv/crowdsec/`** so the GitOps clone stays disposable. Templates and the deploy script stay in the repo.

### Layout

| Path | Role |
| :--- | :--- |
| `.../crowdsec/*.yaml` (repo) | Tracked templates (`$VAR` placeholders) |
| `.../crowdsec/deploy_crowdsec.sh` | Inline network vars; sources secrets; renders → `/etc/crowdsec/` |
| `.../crowdsec/crowdsec.env.example` | Secrets template (API keys, MikroTik credentials) |
| `/srv/crowdsec/crowdsec.env` | Real secrets (not in clone) |

### Deployment Strategy

1. **Clone the repository** to `/opt/homelab-repo`.
2. **Create the secrets file**:
   ```bash
   sudo mkdir -p /srv/crowdsec
   sudo cp /opt/homelab-repo/nodes/reverse-proxy/services/crowdsec/crowdsec.env.example /srv/crowdsec/crowdsec.env
   sudo chmod 600 /srv/crowdsec/crowdsec.env
   # edit /srv/crowdsec/crowdsec.env with real API keys / MikroTik credentials
   ```
3. **Run the deploy script**:
   ```bash
   sudo /opt/homelab-repo/nodes/reverse-proxy/services/crowdsec/deploy_crowdsec.sh
   ```

   This will:
   - Source `/srv/crowdsec/crowdsec.env` for secrets
   - Inject inline network vars + secrets into YAML templates via `envsubst`
   - Restart `crowdsec`, firewall bouncer, and MikroTik bouncer (if present)

To change LAPI bind, trusted subnet, or MikroTik address, edit the topology block at the top of `deploy_crowdsec.sh` and re-run the script.

> [!NOTE]
> Do **not** symlink rendered YAML into `/etc/crowdsec/` from the repo. Always use `deploy_crowdsec.sh` after template or secret changes.
