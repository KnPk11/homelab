# Gatus Deployment Notes

## Deployment Strategy
1. **Clone the repository** to a central location on the node (e.g., `/opt/homelab-repo`).
2. **Create the Environment File**:
   Copy the example environment file and fill it with your node IPs and domain name:
   ```bash
   cp /opt/homelab-repo/nodes/caddy-101/services/Gatus/gatus.env.example /opt/homelab-repo/nodes/caddy-101/services/Gatus/gatus.env
   ```
3. **Run the Deployment Script**:
   Execute the `deploy_gatus.sh` script to render the YAML template securely using `envsubst` and apply it to the system:
   ```bash
   sudo /opt/homelab-repo/nodes/caddy-101/services/Gatus/deploy_gatus.sh
   ```

> [!NOTE]
> Gatus's configuration file requires `envsubst` deployment to substitute your internal IPs and domain securely without tracking them in git. Do not symlink it directly.
