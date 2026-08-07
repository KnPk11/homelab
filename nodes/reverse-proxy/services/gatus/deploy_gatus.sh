#!/bin/bash
# =============================================================================
# deploy_gatus.sh
# Version: 1.4
# Date: 2026-07-27
#
# Render Gatus config.yaml (inline node IPs + /srv/gatus/gatus.env secrets)
# and restart the gatus service.
#
# Usage:
#   sudo ./deploy_gatus.sh
# =============================================================================
SCRIPT_DIR="$(dirname "$(readlink -f "$0")")"
ENV_FILE="/srv/gatus/gatus.env"

set -euo pipefail

# ── Network Topology ─────────────────────────────────────────────
DNS_NODE_IP=192.168.50.102
AITOOLS_NODE_IP=192.168.50.105
HOMELAB_NODE_IP=192.168.50.95
OPENCLAW_NODE_IP=192.168.50.91
OMV_NODE_IP=192.168.50.90
PULSE_NODE_IP=192.168.50.88
MINI_K8S_NODE_IP=192.168.50.96
SCRATCH_PC_NODE_IP=192.168.50.85
export DNS_NODE_IP AITOOLS_NODE_IP HOMELAB_NODE_IP OPENCLAW_NODE_IP OMV_NODE_IP PULSE_NODE_IP MINI_K8S_NODE_IP SCRATCH_PC_NODE_IP

if [ ! -f "$ENV_FILE" ]; then
    echo "Error: $ENV_FILE does not exist. Copy gatus.env.example there and fill your secrets:"
    echo "  sudo mkdir -p /srv/gatus"
    echo "  sudo cp $SCRIPT_DIR/gatus.env.example /srv/gatus/gatus.env"
    echo "  sudo chmod 600 /srv/gatus/gatus.env"
    exit 1
fi

# Load secrets and export for envsubst
set -a
# shellcheck source=/dev/null
source "$ENV_FILE"
set +a
export DOMAIN_NAME

# Deploy config.yaml via envsubst
echo "Deploying config.yaml..."
mkdir -p /srv/gatus
envsubst < "$SCRIPT_DIR/config.yaml" > /srv/gatus/config.yaml

echo "Restarting gatus..."
systemctl restart gatus

echo "Deployment complete."
