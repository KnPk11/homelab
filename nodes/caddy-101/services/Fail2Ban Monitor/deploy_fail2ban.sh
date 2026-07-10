#!/bin/bash
# Fail2Ban Deployment Script
# Secrets live under /srv/fail2ban-monitor/ (not in the disposable GitOps clone).
SCRIPT_DIR="$(dirname "$(readlink -f "$0")")"
ENV_FILE="/srv/fail2ban-monitor/fail2ban.env"

if [ ! -f "$ENV_FILE" ]; then
    echo "Error: $ENV_FILE does not exist. Copy fail2ban.env.example there and fill your secrets:"
    echo "  sudo mkdir -p /srv/fail2ban-monitor"
    echo "  sudo cp \"$SCRIPT_DIR/fail2ban.env.example\" /srv/fail2ban-monitor/fail2ban.env"
    echo "  sudo chmod 600 /srv/fail2ban-monitor/fail2ban.env"
    exit 1
fi

set -a
# shellcheck source=/dev/null
source "$ENV_FILE"
set +a
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
