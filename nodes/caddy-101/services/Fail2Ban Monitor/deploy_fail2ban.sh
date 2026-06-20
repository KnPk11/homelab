#!/bin/bash
# Fail2Ban Deployment Script
SCRIPT_DIR="$(dirname "$(readlink -f "$0")")"
ENV_FILE="$SCRIPT_DIR/fail2ban.env"

if [ ! -f "$ENV_FILE" ]; then
    echo "Error: $ENV_FILE does not exist. Please copy fail2ban.env.example and fill your secrets."
    exit 1
fi

set -a
source "$ENV_FILE"
set +a
export HOMELAB_SUBNETS

# Deploy jail.local via envsubst
envsubst < "$SCRIPT_DIR/jail.local" > /etc/fail2ban/jail.local

# Symlink the action config
ln -sf "$SCRIPT_DIR/crowdsec_action.conf" /etc/fail2ban/action.d/crowdsec.conf

# Symlink the python monitor
ln -sf "$SCRIPT_DIR/fail2ban_bans.py" /srv/fail2ban-monitor/fail2ban_bans.py

echo "Restarting fail2ban..."
systemctl restart fail2ban
systemctl restart fail2ban-monitor
