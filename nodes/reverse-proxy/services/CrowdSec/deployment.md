# CrowdSec Deployment Notes

## Configuration Templates

CrowdSec configs (e.g. `config.yaml`, bouncers) do not read a `.env` at runtime. We render secrets into `/etc/crowdsec/` with `envsubst` via `deploy_crowdsec.sh`.

Secrets live under **`/srv/crowdsec/`** so the GitOps clone stays disposable. Templates and the deploy script stay in the repo.

### Layout

| Path | Role |
| :--- | :--- |
| `.../CrowdSec/*.yaml` (repo) | Tracked templates (`$VAR` placeholders) |
| `.../CrowdSec/crowdsec.env.example` | Template only |
| `.../CrowdSec/deploy_crowdsec.sh` | Renders templates → `/etc/crowdsec/` |
| `/srv/crowdsec/crowdsec.env` | Real secrets (not in clone) |

### Deployment Strategy

1. **Clone the repository** to `/opt/homelab-repo`.
2. **Create the environment file** under the service directory:
   ```bash
   sudo mkdir -p /srv/crowdsec
   sudo cp /opt/homelab-repo/nodes/reverse-proxy/services/CrowdSec/crowdsec.env.example /srv/crowdsec/crowdsec.env
   sudo chmod 600 /srv/crowdsec/crowdsec.env
   # edit /srv/crowdsec/crowdsec.env with real values
   ```
3. **Run the deploy script** (sources `/srv/crowdsec/crowdsec.env`, restarts services):
   ```bash
   sudo /opt/homelab-repo/nodes/reverse-proxy/services/CrowdSec/deploy_crowdsec.sh
   ```

> [!NOTE]
> Do **not** symlink rendered YAML into `/etc/crowdsec/` from the repo. Always use `deploy_crowdsec.sh` after template or secret changes.
