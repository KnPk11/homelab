# OMV Firewall Deployment

1. On `nas`, decrypt the SOPS-encrypted firewall environment file:
   ```bash
   sops -d /opt/homelab-repo/nodes/nas/scripts/firewall.env > /opt/homelab-repo/nodes/nas/scripts/firewall.env
   ```

2. Symlink the script to an execution path:
   ```bash
   ln -s /opt/homelab-repo/nodes/nas/scripts/firewall.sh /usr/local/bin/firewall
   chmod +x /opt/homelab-repo/nodes/nas/scripts/firewall.sh
   ```

3. Run the firewall script to apply the rules to the OMV backend:
   ```bash
   sudo firewall
   ```
