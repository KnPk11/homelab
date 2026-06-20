#!/bin/bash
# Gatus Deployment Script
SCRIPT_DIR="$(dirname "$(readlink -f "$0")")"
ENV_FILE="$SCRIPT_DIR/gatus.env"

if [ ! -f "$ENV_FILE" ]; then
    echo "Error: $ENV_FILE does not exist. Please copy gatus.env.example and fill your secrets."
    exit 1
fi

# Load variables and export them
set -a
source "$ENV_FILE"
set +a
export DOMAIN_NAME DNS_NODE_IP AITOOLS_NODE_IP HOMELAB_NODE_IP OPENCLAW_NODE_IP OMV_NODE_IP

# Deploy config.yaml via envsubst
echo "Deploying config.yaml..."
envsubst < "$SCRIPT_DIR/config.yaml" > /opt/gatus/config.yaml

echo "Restarting gatus..."
systemctl restart gatus

echo "Deployment complete."
