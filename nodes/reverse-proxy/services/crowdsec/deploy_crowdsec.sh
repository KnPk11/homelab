#!/bin/bash
# =============================================================================
# deploy_crowdsec.sh
# Version: 1.3
# Date: 2026-07-27
#
# Render CrowdSec + bouncer configs via envsubst (inline network topology +
# /srv/crowdsec/crowdsec.env secrets) and restart CrowdSec services.
#
# Usage:
#   sudo ./deploy_crowdsec.sh
# =============================================================================
SCRIPT_DIR="$(dirname "$(readlink -f "$0")")"
ENV_FILE="/srv/crowdsec/crowdsec.env"

set -euo pipefail

# ── Network Topology ─────────────────────────────────────────────
CROWDSEC_LAPI_URL_PORT=192.168.50.101:8080
HOMELAB_SUBNET=192.168.50.0/24
MIKROTIK_ADDRESS=192.168.88.1:8728
export CROWDSEC_LAPI_URL_PORT HOMELAB_SUBNET MIKROTIK_ADDRESS

if [ ! -f "$ENV_FILE" ]; then
    echo "Error: $ENV_FILE does not exist. Copy crowdsec.env.example there and fill your secrets:"
    echo "  sudo mkdir -p /srv/crowdsec"
    echo "  sudo cp $SCRIPT_DIR/crowdsec.env.example /srv/crowdsec/crowdsec.env"
    echo "  sudo chmod 600 /srv/crowdsec/crowdsec.env"
    exit 1
fi

# Load secrets
set -a
# shellcheck source=/dev/null
source "$ENV_FILE"
set +a

# Export secrets explicitly for envsubst
export CROWDSEC_FIREWALL_API_KEY CROWDSEC_ROUTEROS_API_KEY MIKROTIK_USERNAME MIKROTIK_PASSWORD

echo "Deploying config.yaml..."
envsubst < "$SCRIPT_DIR/config.yaml" > /etc/crowdsec/config.yaml

echo "Deploying acquis.yaml..."
envsubst < "$SCRIPT_DIR/acquis.yaml" > /etc/crowdsec/acquis.yaml

echo "Deploying firewall bouncer..."
envsubst < "$SCRIPT_DIR/crowdsec-firewall-bouncer.yaml" > /etc/crowdsec/bouncers/crowdsec-firewall-bouncer.yaml

echo "Deploying RouterOS bouncer..."
envsubst < "$SCRIPT_DIR/cs-routeros-bouncer.yaml" > /etc/crowdsec/bouncers/cs-routeros-bouncer.yaml

echo "Setting permissions..."
chmod 600 /etc/crowdsec/bouncers/*.yaml

echo "Restarting services..."
systemctl restart crowdsec
systemctl restart crowdsec-firewall-bouncer
# Prefer the live unit name. Legacy cs-routeros-bouncer may be masked (duplicate
# that fought crowdsec-mikrotik-bouncer for :2112); never restart a masked unit.
if systemctl cat crowdsec-mikrotik-bouncer.service &>/dev/null; then
    systemctl restart crowdsec-mikrotik-bouncer
elif systemctl cat cs-routeros-bouncer.service &>/dev/null \
    && ! systemctl is-enabled cs-routeros-bouncer.service 2>/dev/null | grep -qx masked; then
    systemctl restart cs-routeros-bouncer
else
    echo "Warning: no active RouterOS/MikroTik bouncer unit found to restart."
fi

echo "Deployment complete."
