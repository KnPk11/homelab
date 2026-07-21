#!/bin/bash
# deploy_app.sh — renders profiles; secrets live under /srv/dbt/

SCRIPT_DIR="$(dirname "$(readlink -f "$0")")"
ENV_FILE="/srv/dbt/.env"
DEST_DIR="/srv/dbt"

if [ ! -f "$ENV_FILE" ]; then
    echo "Error: $ENV_FILE not found. Copy .env.example there and configure it:"
    echo "  sudo mkdir -p $DEST_DIR"
    echo "  sudo cp $SCRIPT_DIR/.env.example $DEST_DIR/.env"
    echo "  sudo chmod 600 $DEST_DIR/.env"
    exit 1
fi

set -a
# shellcheck source=/dev/null
source "$ENV_FILE"
set +a

sudo mkdir -p "$DEST_DIR"

echo "Deploying profiles.yml to $DEST_DIR/profiles.yml..."
envsubst < "$SCRIPT_DIR/profiles.yml" | sudo tee "$DEST_DIR/profiles.yml" > /dev/null

# Expect secrets already on the host under /srv/dbt/.secrets/ (not in the clone):
#   postgres_password.secret, gcp-creds.json
if [ ! -f "$DEST_DIR/.secrets/postgres_password.secret" ]; then
    echo "Warning: $DEST_DIR/.secrets/postgres_password.secret missing"
fi
if [ ! -f "$DEST_DIR/.secrets/gcp-creds.json" ]; then
    echo "Warning: $DEST_DIR/.secrets/gcp-creds.json missing"
fi

echo "Deployment complete."
