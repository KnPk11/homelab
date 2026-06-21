# OpenClaw Firewall Deployment

1. On `openclaw-91`, copy the example environment file and edit it to include your actual values:
   ```bash
   cp /opt/homelab-repo/nodes/openclaw-91/scripts/ufw.env.example /opt/homelab-repo/nodes/openclaw-91/scripts/ufw.env
   nano /opt/homelab-repo/nodes/openclaw-91/scripts/ufw.env
   ```

2. Symlink the script to an execution path:
   ```bash
   sudo ln -s /opt/homelab-repo/nodes/openclaw-91/scripts/ufw.sh /usr/local/bin/firewall
   sudo chmod +x /opt/homelab-repo/nodes/openclaw-91/scripts/ufw.sh
   ```

3. Run the firewall script to apply the rules:
   ```bash
   sudo firewall
   ```
