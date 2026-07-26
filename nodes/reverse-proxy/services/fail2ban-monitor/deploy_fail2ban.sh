#!/bin/bash
# Fail2Ban Deployment Script
# Network topology is defined inline (canonical reference: inventory.yml).
# Monitor code is symlinked under /srv/fail2ban-monitor/ from the GitOps clone.
SCRIPT_DIR="$(dirname "$(readlink -f "$0")")"

set -euo pipefail

# ── Network Topology ─────────────────────────────────────────────
# ignoreip whitelist for jail.local (same class of data as UFW scripts)
HOMELAB_SUBNETS="::1 192.168.88.0/24 192.168.50.0/24 172.16.0.0/12 10.5.0.0/24 10.6.0.0/24 100.64.0.0/10"
export HOMELAB_SUBNETS

# Deploy jail.local via envsubst
envsubst < "$SCRIPT_DIR/jail.local" > /etc/fail2ban/jail.local

# Symlink the action config
ln -sf "$SCRIPT_DIR/crowdsec_action.conf" /etc/fail2ban/action.d/crowdsec.conf

# Symlink the python monitor (tracked code; stays in clone)
mkdir -p /srv/fail2ban-monitor
ln -sf "$SCRIPT_DIR/fail2ban_bans.py" /srv/fail2ban-monitor/fail2ban_bans.py

echo "Restarting fail2ban..."
systemctl restart fail2ban
systemctl restart fail2ban-monitor

echo "Deployment complete."
