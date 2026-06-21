# OMV Firewall Deployment

1. On `omv-90`, copy the example environment file and edit it to include your actual values:
   ```bash
   cp /opt/homelab-repo/nodes/omv-90/scripts/firewall.env.example /opt/homelab-repo/nodes/omv-90/scripts/firewall.env
   nano /opt/homelab-repo/nodes/omv-90/scripts/firewall.env
   ```

2. Symlink the script to an execution path:
   ```bash
   ln -s /opt/homelab-repo/nodes/omv-90/scripts/firewall.sh /usr/local/bin/firewall
   chmod +x /opt/homelab-repo/nodes/omv-90/scripts/firewall.sh
   ```

3. Run the firewall script to apply the rules to the OMV backend:
   ```bash
   sudo firewall
   ```
