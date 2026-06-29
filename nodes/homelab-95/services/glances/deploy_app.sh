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

DEST_DIR="/srv/glances"
sudo mkdir -p "$DEST_DIR"

# Deploy glances.conf
echo "Deploying glances.conf to $DEST_DIR/glances.conf..."
envsubst < "$SCRIPT_DIR/glances.conf" | sudo tee "$DEST_DIR/glances.conf" > /dev/null

# Symlink .env
echo "Symlinking .env to $DEST_DIR/.env..."
sudo ln -sf "$ENV_FILE" "$DEST_DIR/.env"

# Note: glances.pwd is handled manually or via a separate secrets deployment script.
# If it lives in $SCRIPT_DIR/glances.pwd, uncomment below:
# if [ -f "$SCRIPT_DIR/glances.pwd" ]; then
#     echo "Deploying glances.pwd..."
#     sudo cp "$SCRIPT_DIR/glances.pwd" "$DEST_DIR/glances.pwd"
#     sudo chmod 600 "$DEST_DIR/glances.pwd"
# fi

echo "Deployment complete."
