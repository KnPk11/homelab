#!/bin/bash
# deploy_app.sh — renders templates; secrets live under /srv/mediamtx/

SCRIPT_DIR="$(dirname "$(readlink -f "$0")")"
ENV_FILE="/srv/mediamtx/.env"

if [ ! -f "$ENV_FILE" ]; then
    echo "Error: $ENV_FILE not found. Copy .env.example there and configure it:"
    echo "  sudo mkdir -p /srv/mediamtx"
    echo "  sudo cp $SCRIPT_DIR/.env.example /srv/mediamtx/.env"
    echo "  sudo chmod 600 /srv/mediamtx/.env"
    exit 1
fi

set -a
# shellcheck source=/dev/null
source "$ENV_FILE"
set +a

DEST_DIR="/srv/mediamtx"
sudo mkdir -p "$DEST_DIR"

if [ -f "$SCRIPT_DIR/entrypoint.sh" ]; then
    echo "Symlinking entrypoint.sh to $DEST_DIR/entrypoint.sh..."
    sudo ln -sfn "$SCRIPT_DIR/entrypoint.sh" "$DEST_DIR/entrypoint.sh"
fi

if [ -f "$SCRIPT_DIR/mediamtx.yml" ]; then
    echo "Templating mediamtx.yml to $DEST_DIR/mediamtx.yml..."
    envsubst < "$SCRIPT_DIR/mediamtx.yml" | sudo tee "$DEST_DIR/mediamtx.yml" > /dev/null
fi

echo "Deployment complete. Secrets stay in $DEST_DIR (not the GitOps clone)."
