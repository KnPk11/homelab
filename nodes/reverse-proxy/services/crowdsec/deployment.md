# CrowdSec Deployment Notes

## Configuration Templates

CrowdSec configs (e.g. `config.yaml`, bouncers) do not read a `.env` at runtime. We render them into `/etc/crowdsec/` with `envsubst` via `deploy_crowdsec.sh`.

Network topology (LAPI URL, trusted subnet, MikroTik address) is defined inline in `deploy_crowdsec.sh` — same approach as the UFW scripts. Secrets live under **`/srv/crowdsec/`** so the GitOps clone stays disposable. Templates and the deploy script stay in the repo.

### Layout

| Path | Role |
| :--- | :--- |
| `.../crowdsec/*.yaml` (repo) | Tracked templates (`$VAR` placeholders) |
| `.../crowdsec/deploy_crowdsec.sh` | Inline network vars; sources secrets; renders → `/etc/crowdsec/` |
| `.../crowdsec/crowdsec.env.example` | Secrets template (API keys, MikroTik credentials, Telegram) |
| `.../crowdsec/http.yaml` | Telegram notification template (`TELEGRAM_*` via envsubst) |
| `.../crowdsec/profiles.yaml` | Ban profiles; `http_default` notifications enabled |
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

### Allowlist (`my-trusted-ips`)

LAPI database, not Git. After a nuke-and-pave, re-add:

```bash
cscli allowlists add my-trusted-ips 192.168.88.0/24 -d "Main LAN"
cscli allowlists add my-trusted-ips 192.168.50.0/24 -d "Homelab LAN"
cscli allowlists add my-trusted-ips 10.5.0.0/24 -d "WireGuard"
cscli allowlists add my-trusted-ips 100.64.0.0/10 -d "Tailscale"
# Current residential WAN — changes with DDNS; add/replace when the IP moves
# cscli allowlists add my-trusted-ips [WAN-IP] -d "Current WAN (update when IP changes)"
```

Telegram: `profiles.yaml` enables `http_default`. Ban lines are prefixed `🌐`. After deploy:

```bash
TMPDIR=/tmp cscli notifications test http_default
```

(`cscli` as root needs `TMPDIR=/tmp` or the HTTP plugin fails on `/tmp/user/0`.) The CrowdSec service itself already registered `http_default` at start.

> [!NOTE]
> Do **not** symlink rendered YAML into `/etc/crowdsec/` from the repo. Always use `deploy_crowdsec.sh` after template or secret changes.
