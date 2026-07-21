#!/bin/bash
# deploy_app.sh
# Renders templates and deploys config files to destination paths

SCRIPT_DIR="$(dirname "$(readlink -f "$0")")"
ENV_FILE="$SCRIPT_DIR/.env"

if [ ! -f "$ENV_FILE" ]; then
    echo "Error: .env file not found. Please copy .env.example to .env and configure it."
    exit 1
fi

DEST_DIR="/srv/grafana"
sudo mkdir -p "$DEST_DIR"

# Symlink .env
echo "Symlinking .env to $DEST_DIR/.env..."
sudo ln -sf "$ENV_FILE" "$DEST_DIR/.env"

if [ -f "$SCRIPT_DIR/grafana_password.secret" ]; then
    echo "Symlinking grafana_password.secret to $DEST_DIR/grafana_password.secret..."
    sudo ln -sf "$SCRIPT_DIR/grafana_password.secret" "$DEST_DIR/grafana_password.secret"
fi

# Loki Config
if [ -f "$SCRIPT_DIR/loki-config.yaml" ]; then
    echo "Symlinking loki-config.yaml to $DEST_DIR/loki-config.yaml..."
    sudo ln -sf "$SCRIPT_DIR/loki-config.yaml" "$DEST_DIR/loki-config.yaml"
fi

# Promtail Config
if [ -f "$SCRIPT_DIR/promtail-config.yaml" ]; then
    echo "Symlinking promtail-config.yaml to $DEST_DIR/promtail-config.yaml..."
    sudo ln -sf "$SCRIPT_DIR/promtail-config.yaml" "$DEST_DIR/promtail-config.yaml"
fi

echo "Deployment complete."
