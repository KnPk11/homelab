# AdGuardHome Deployment

Because AdGuardHome rewrites its configuration file (`AdGuardHome.yaml`) at runtime whenever you change settings in the web UI, we **cannot** track the live configuration file directly in Git. Doing so would result in constant uncommitted changes on the node. Additionally, the configuration contains a bcrypt password hash which should be kept secret.

## Deployment Strategy

Instead of symlinking, we use a template approach:

1. **`AdGuardHome.template.yaml`**: This file is tracked in Git. It is the full configuration but with the password hash replaced by `{{ADGUARD_PASSWORD_HASH}}`.
2. **`.env`**: A local secrets file created on the `dns-102` node (not tracked in Git) which contains the actual password hash.
3. **`deploy_adguard.sh`**: A script that injects the secret from `.env` into the template and overwrites the live configuration file at `/srv/adguard/AdGuardHome.yaml`.

## Setup Instructions

1. On `dns-102`, copy the example secrets file and edit it to include your actual values:
   ```bash
   cp /opt/homelab-repo/nodes/dns-102/services/adguard/.env.example /opt/homelab-repo/nodes/dns-102/services/adguard/.env
   nano /opt/homelab-repo/nodes/dns-102/services/adguard/.env
   ```
   *(Ensure you use single quotes for the password hash if it contains special characters)*

3. Run the deployment script:
   ```bash
   cd /opt/homelab-repo/nodes/dns-102/services/adguard
   ./deploy_adguard.sh
   ```

## Updating Configuration

If you make changes in the AdGuard web UI that you want to persist across deployments (e.g. adding a new DNS rewrite or filter list):

1. Copy the relevant changes from the live `/srv/adguard/AdGuardHome.yaml` back into `AdGuardHome.template.yaml`.
2. Be careful not to copy the password hash back into the template!
3. Commit and push the template updates to Git.
