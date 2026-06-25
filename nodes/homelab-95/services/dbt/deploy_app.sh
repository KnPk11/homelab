#!/bin/bash
# deploy_app.sh
# Renders templates and deploys config files to destination paths

SCRIPT_DIR="$(dirname "$(readlink -f "$0")")"
ENV_FILE="$SCRIPT_DIR/.env"

if [ ! -f "$ENV_FILE" ]; then
    echo "Error: .env file not found. Please copy .env.example to .env and configure it."
    exit 1
fi

# Export variables from .env so envsubst can use them
set -a
source "$ENV_FILE"
set +a

DEST_DIR="/srv/dbt"
sudo mkdir -p "$DEST_DIR"

# Deploy profiles.yml
echo "Deploying profiles.yml to $DEST_DIR/profiles.yml..."
envsubst < "$SCRIPT_DIR/profiles.yml" | sudo tee "$DEST_DIR/profiles.yml" > /dev/null

echo "Deployment complete."
