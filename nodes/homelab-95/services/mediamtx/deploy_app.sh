#!/bin/bash
# deploy_app.sh
# Renders templates and deploys config files to destination paths

SCRIPT_DIR="$(dirname "$(readlink -f "$0")")"
ENV_FILE="$SCRIPT_DIR/.env"

if [ ! -f "$ENV_FILE" ]; then
    echo "Error: .env file not found. Please copy .env.example to .env and configure it."
    exit 1
fi

# Load variables for envsubst
export $(grep -v '^#' "$ENV_FILE" | xargs)

DEST_DIR="/srv/mediamtx"
sudo mkdir -p "$DEST_DIR"

echo "Symlinking .env to $DEST_DIR/.env..."
sudo ln -sf "$ENV_FILE" "$DEST_DIR/.env"

if [ -f "$SCRIPT_DIR/mediamtx_password.secret" ]; then
    echo "Symlinking mediamtx_password.secret to $DEST_DIR/mediamtx_password.secret..."
    sudo ln -sf "$SCRIPT_DIR/mediamtx_password.secret" "$DEST_DIR/mediamtx_password.secret"
fi

if [ -f "$SCRIPT_DIR/entrypoint.sh" ]; then
    echo "Symlinking entrypoint.sh to $DEST_DIR/entrypoint.sh..."
    sudo ln -sf "$SCRIPT_DIR/entrypoint.sh" "$DEST_DIR/entrypoint.sh"
fi

# Template mediamtx.yml
if [ -f "$SCRIPT_DIR/mediamtx.yml" ]; then
    echo "Templating mediamtx.yml to $DEST_DIR/mediamtx.yml..."
    envsubst < "$SCRIPT_DIR/mediamtx.yml" | sudo tee "$DEST_DIR/mediamtx.yml" > /dev/null
fi

echo "Deployment complete."
