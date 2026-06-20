# CrowdSec Deployment Notes

## Configuration Templates
CrowdSec configurations (like `config.yaml` and bouncers) do not natively support reading dynamic variables from a `.env` file. Therefore, they cannot be safely symlinked from the repository while keeping secrets secure.

We use an `envsubst` deployment strategy to inject the secrets directly into the YAML files during deployment.

### Deployment Strategy
1. **Clone the repository** to a central location on the node (e.g., `/opt/homelab-repo`).
2. **Create the Environment File**:
   Copy the example environment file and fill it with your actual API keys and subnets:
   ```bash
   cp /opt/homelab-repo/nodes/caddy-101/services/CrowdSec/crowdsec.env.example /opt/homelab-repo/nodes/caddy-101/services/CrowdSec/crowdsec.env
   ```
3. **Run the Deployment Script**:
   Execute the `deploy_crowdsec.sh` script to render the YAML templates and restart the CrowdSec services automatically:
   ```bash
   sudo /opt/homelab-repo/nodes/caddy-101/services/CrowdSec/deploy_crowdsec.sh
   ```

> [!NOTE]
> Do NOT symlink these YAML files directly to `/etc/crowdsec/`. Always use the `deploy_crowdsec.sh` script when you pull new updates from the repository.
