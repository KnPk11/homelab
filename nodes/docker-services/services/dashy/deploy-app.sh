#!/bin/bash
# =============================================================================
# deploy_app.sh
# Version: 1.2
# Date: 2026-07-10
#
# Render Dashy config.yml from template using /srv/dashy/dashy.env secrets
# (docker-services host).
#
# Usage:
#   sudo ./deploy_app.sh
# =============================================================================
SCRIPT_DIR="$(dirname "$(readlink -f "$0")")"
ENV_FILE="/srv/dashy/dashy.env"
TEMPLATE_FILE="$SCRIPT_DIR/config.yml.tmpl"
TARGET_FILE="/srv/dashy/config.yml"

if [ ! -f "$ENV_FILE" ]; then
    echo "Error: $ENV_FILE not found. Copy dashy.env.example there and fill it out:"
    echo "  sudo mkdir -p /srv/dashy"
    echo "  sudo cp $SCRIPT_DIR/dashy.env.example /srv/dashy/dashy.env"
    echo "  sudo chmod 600 /srv/dashy/dashy.env"
    exit 1
fi

if [ ! -f "$TEMPLATE_FILE" ]; then
    echo "Error: Template file $TEMPLATE_FILE not found."
    exit 1
fi

echo "Injecting variables from $ENV_FILE into $TEMPLATE_FILE..."
set -a
# shellcheck source=/dev/null
source "$ENV_FILE"
set +a

mkdir -p /srv/dashy
envsubst < "$TEMPLATE_FILE" > "$TARGET_FILE"

echo "Deployment complete! Dashy will automatically hot-reload the changes from $TARGET_FILE."
