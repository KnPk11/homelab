#!/bin/bash
# =============================================================================
# deploy_fail2ban.sh
# Version: 1.3
# Date: 2026-08-29
#
# Deploy Fail2Ban jail.local (inline HOMELAB_SUBNETS via envsubst), symlink
# CrowdSec action + ban monitor script, restart fail2ban and fail2ban-monitor.
#
# Usage:
#   sudo ./deploy_fail2ban.sh
# =============================================================================
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
touch /srv/fail2ban-monitor/banned-history.jsonl
chmod 644 /srv/fail2ban-monitor/banned-history.jsonl

echo "Restarting fail2ban..."
systemctl restart fail2ban
systemctl restart fail2ban-monitor

echo "Deployment complete."
