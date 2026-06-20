# Fail2Ban Monitor Deployment Notes

## Deployment Strategy
1. **Clone the repository** to a central location on the node (e.g., `/opt/homelab-repo`).
2. **Create the Environment File**:
   Copy the example environment file and update it with your actual homelab subnets to avoid banning yourself:
   ```bash
   cp "/opt/homelab-repo/nodes/caddy-101/services/Fail2Ban Monitor/fail2ban.env.example" "/opt/homelab-repo/nodes/caddy-101/services/Fail2Ban Monitor/fail2ban.env"
   ```
3. **Run the Deployment Script**:
   Execute the `deploy_fail2ban.sh` script. This script will:
   - Render your `jail.local` securely using `envsubst` to inject your subnets.
   - Symlink `crowdsec_action.conf` and `fail2ban_bans.py` directly to the system.
   - Restart the fail2ban and monitor services automatically.
   
   ```bash
   sudo "/opt/homelab-repo/nodes/caddy-101/services/Fail2Ban Monitor/deploy_fail2ban.sh"
   ```
