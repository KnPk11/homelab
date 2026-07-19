#!/bin/bash
# Deploy Dashy (static build) to caddy-101
# Uses envsubst to generate conf.yml into /srv/dashy/dist and /srv/dashy/user-data/
#
# Pre-built dist is SCP'd from ai-tools-105 (or rebuilt locally).
#
# Usage: sudo ./deploy_dashy.sh

set -euo pipefail

SCRIPT_DIR="$(dirname "$(readlink -f "$0")")"
DASHY_ROOT="/srv/dashy"
ENV_FILE="/srv/dashy/dashy.env"
TEMPLATE_FILE="$SCRIPT_DIR/config.yml.tmpl"

echo "=== Dashy Static Deploy ==="

if [ ! -f "$ENV_FILE" ]; then
    echo "Error: $ENV_FILE not found. Copy dashy.env.example there and fill it out:"
    echo "  sudo mkdir -p /srv/dashy"
    echo "  sudo cp $SCRIPT_DIR/dashy.env.example /srv/dashy/dashy.env"
    echo "  sudo chmod 600 /srv/dashy/dashy.env"
    exit 1
fi

# Ensure dist exists (SCP'd from build host)
if [ ! -d "$DASHY_ROOT/dist" ]; then
    echo "Error: $DASHY_ROOT/dist not found."
    echo "Build Dashy on ai-tools-105 and SCP the dist folder:"
    echo "  scp -r /tmp/dashy-build/dist root@192.168.50.101:/srv/dashy/dist"
    exit 1
fi

# Load env vars
set -a
# shellcheck source=/dev/null
source "$ENV_FILE"
set +a

# Deploy config
echo "Deploying config from template..."
mkdir -p "$DASHY_ROOT/user-data"
envsubst < "$TEMPLATE_FILE" > "$DASHY_ROOT/user-data/conf.yml"
cp "$DASHY_ROOT/user-data/conf.yml" "$DASHY_ROOT/dist/conf.yml"

echo "Reloading Caddy..."
systemctl reload caddy

echo "Deployment complete! Dashy is served as static files by Caddy."
echo "Visit: https://home.\$DOMAIN_NAME"
