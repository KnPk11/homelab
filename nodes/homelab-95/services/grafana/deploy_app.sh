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
LOKI_DEST="/srv/loki"
sudo mkdir -p "$LOKI_DEST"
if [ -f "$SCRIPT_DIR/loki-config.yaml" ]; then
    echo "Deploying loki-config.yaml to $LOKI_DEST/loki-config.yaml..."
    sudo cp "$SCRIPT_DIR/loki-config.yaml" "$LOKI_DEST/loki-config.yaml"
fi

# Promtail Config
PROMTAIL_DEST="/srv/promtail"
sudo mkdir -p "$PROMTAIL_DEST"
if [ -f "$SCRIPT_DIR/promtail-config.yaml" ]; then
    echo "Deploying promtail-config.yaml to $PROMTAIL_DEST/promtail-config.yaml..."
    sudo cp "$SCRIPT_DIR/promtail-config.yaml" "$PROMTAIL_DEST/promtail-config.yaml"
fi

echo "Deployment complete."
