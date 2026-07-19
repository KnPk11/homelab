#!/bin/bash
# Gatus Deployment Script
# Secrets live under /srv/gatus/ (not in the disposable GitOps clone).
SCRIPT_DIR="$(dirname "$(readlink -f "$0")")"
ENV_FILE="/srv/gatus/gatus.env"

if [ ! -f "$ENV_FILE" ]; then
    echo "Error: $ENV_FILE does not exist. Copy gatus.env.example there and fill your secrets:"
    echo "  sudo mkdir -p /srv/gatus"
    echo "  sudo cp $SCRIPT_DIR/gatus.env.example /srv/gatus/gatus.env"
    echo "  sudo chmod 600 /srv/gatus/gatus.env"
    exit 1
fi

# Load variables and export them
set -a
# shellcheck source=/dev/null
source "$ENV_FILE"
set +a
export DOMAIN_NAME DNS_NODE_IP AITOOLS_NODE_IP HOMELAB_NODE_IP OPENCLAW_NODE_IP OMV_NODE_IP PULSE_NODE_IP

# Deploy config.yaml via envsubst
echo "Deploying config.yaml..."
mkdir -p /srv/gatus
envsubst < "$SCRIPT_DIR/config.yaml" > /srv/gatus/config.yaml

echo "Restarting gatus..."
systemctl restart gatus

echo "Deployment complete."
