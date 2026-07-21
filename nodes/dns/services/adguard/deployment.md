# AdGuardHome Deployment

Because AdGuardHome rewrites its configuration file (`AdGuardHome.yaml`) at runtime whenever you change settings in the web UI, we **cannot** track the live configuration file directly in Git. Doing so would result in constant uncommitted changes on the node. Additionally, the configuration contains a bcrypt password hash which should be kept secret.

Secrets live under **`/srv/adguard/`** so the GitOps clone stays disposable. The template and deploy script stay in the repo.

## Layout

| Path | Role |
| :--- | :--- |
| `.../adguard/AdGuardHome.template.yaml` | Tracked template (`{{ADGUARD_PASSWORD_HASH}}`, IPs, domain) |
| `.../adguard/adguard.env.example` | Template only |
| `.../adguard/deploy_adguard.sh` | Injects secrets → live YAML + restarts service |
| `/srv/adguard/adguard.env` | Real secrets (not in clone) |
| `/srv/adguard/AdGuardHome.yaml` | Live config (written by deploy + AdGuard UI) |
| `/srv/adguard/AdGuardHome` | Binary |

## Setup Instructions

1. On `dns`, create the secrets file under the service directory:
   ```bash
   sudo mkdir -p /srv/adguard
   sudo cp /opt/homelab-repo/nodes/dns/services/adguard/adguard.env.example /srv/adguard/adguard.env
   sudo chmod 600 /srv/adguard/adguard.env
   sudo nano /srv/adguard/adguard.env
   ```
   *(Use single quotes for the password hash if it contains special characters.)*

2. Run the deployment script:
   ```bash
   sudo /opt/homelab-repo/nodes/dns/services/adguard/deploy_adguard.sh
   ```

## Updating Configuration

If you make changes in the AdGuard web UI that you want to persist across deployments (e.g. adding a new DNS rewrite or filter list):

1. Copy the relevant changes from the live `/srv/adguard/AdGuardHome.yaml` back into `AdGuardHome.template.yaml`.
2. Be careful not to copy the password hash back into the template!
3. Commit and push the template updates to Git.
