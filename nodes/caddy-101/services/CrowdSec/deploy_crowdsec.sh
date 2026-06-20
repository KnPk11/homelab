#!/bin/bash
# CrowdSec Deployment Script
SCRIPT_DIR="$(dirname "$(readlink -f "$0")")"
ENV_FILE="$SCRIPT_DIR/crowdsec.env"

if [ ! -f "$ENV_FILE" ]; then
    echo "Error: $ENV_FILE does not exist. Please copy crowdsec.env.example and fill your secrets."
    exit 1
fi

# Load variables
set -a
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
systemctl restart cs-routeros-bouncer

echo "Deployment complete."
