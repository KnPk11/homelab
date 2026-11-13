#!/bin/bash
# =============================================================================
# deploy-app.sh
# Version: 1.2
# Date: 2026-11-13
#
# Symlink non-secret Grafana/Loki/Promtail configs into /srv/grafana/ and
# verify host-local secret files exist there (never symlink from Git clone).
#
# Usage:
#   sudo ./deploy-app.sh
# =============================================================================
set -euo pipefail

SCRIPT_DIR="$(dirname "$(readlink -f "$0")")"
DEST_DIR="/srv/grafana"
ENV_FILE="$DEST_DIR/.env"
SECRET_FILE="$DEST_DIR/grafana_password.secret"

if [ ! -f "$ENV_FILE" ] || [ ! -f "$SECRET_FILE" ]; then
    echo "Error: host-local secrets missing under $DEST_DIR. Populate them first:"
    echo "  sudo install -d -m 755 $DEST_DIR"
    echo "  sudo cp $SCRIPT_DIR/.env.example $ENV_FILE && sudo chmod 600 $ENV_FILE"
    echo "  sudo cp $SCRIPT_DIR/grafana_password.secret.example $SECRET_FILE && sudo chmod 600 $SECRET_FILE"
    exit 1
fi

sudo mkdir -p "$DEST_DIR"

# Loki Config
if [ -f "$SCRIPT_DIR/loki-config.yaml" ]; then
    echo "Symlinking loki-config.yaml to $DEST_DIR/loki-config.yaml..."
    sudo ln -sfn "$SCRIPT_DIR/loki-config.yaml" "$DEST_DIR/loki-config.yaml"
fi

# Promtail Config
if [ -f "$SCRIPT_DIR/promtail-config.yaml" ]; then
    echo "Symlinking promtail-config.yaml to $DEST_DIR/promtail-config.yaml..."
    sudo ln -sfn "$SCRIPT_DIR/promtail-config.yaml" "$DEST_DIR/promtail-config.yaml"
fi

echo "Deployment complete. Secrets remain in $DEST_DIR (not the GitOps clone)."
