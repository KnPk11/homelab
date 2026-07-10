#!/bin/bash
# CrowdSec Deployment Script
# Secrets live under /srv/crowdsec/ (not in the disposable GitOps clone).
SCRIPT_DIR="$(dirname "$(readlink -f "$0")")"
ENV_FILE="/srv/crowdsec/crowdsec.env"

if [ ! -f "$ENV_FILE" ]; then
    echo "Error: $ENV_FILE does not exist. Copy crowdsec.env.example there and fill your secrets:"
    echo "  sudo mkdir -p /srv/crowdsec"
    echo "  sudo cp $SCRIPT_DIR/crowdsec.env.example /srv/crowdsec/crowdsec.env"
    echo "  sudo chmod 600 /srv/crowdsec/crowdsec.env"
    exit 1
fi

# Load variables
set -a
# shellcheck source=/dev/null
source "$ENV_FILE"
set +a

# Export them explicitly for envsubst
export CROWDSEC_LAPI_URL_PORT HOMELAB_SUBNET CROWDSEC_FIREWALL_API_KEY CROWDSEC_ROUTEROS_API_KEY MIKROTIK_ADDRESS MIKROTIK_USERNAME MIKROTIK_PASSWORD

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
# Unit name may be either legacy or mikrotik-prefixed depending on install
if systemctl list-unit-files cs-routeros-bouncer.service &>/dev/null; then
    systemctl restart cs-routeros-bouncer
elif systemctl list-unit-files crowdsec-mikrotik-bouncer.service &>/dev/null; then
    systemctl restart crowdsec-mikrotik-bouncer
fi

echo "Deployment complete."
