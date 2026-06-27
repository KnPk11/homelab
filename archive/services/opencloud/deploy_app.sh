#!/bin/bash
# Description: Deploys the OpenCloud configurations to the host for Portainer to consume.
# Scrapes secrets from .env and rebuilds opencloud.yaml automatically.

TARGET_DIR="/srv/opencloud"

echo "Deploying OpenCloud configurations to $TARGET_DIR..."

sudo mkdir -p "$TARGET_DIR/config"
sudo mkdir -p "$TARGET_DIR/.secrets"

if [ -f ".env" ]; then
    echo "Found .env secrets file! Rebuilding opencloud.yaml..."
    
    # Export the variables from the .env file so envsubst can use them
    set -a
    source .env
    set +a
    
    # Generate the actual opencloud.yaml into the target config directory
    envsubst < opencloud.yaml.example | sudo tee "$TARGET_DIR/.secrets/opencloud.yaml" > /dev/null
    
    # Also copy the .env over for Portainer
    sudo cp .env "$TARGET_DIR/.secrets/.env"
    
    sudo chmod -R 600 "$TARGET_DIR/.secrets"
    echo "Secrets securely generated and deployed."
else
    echo "No .env file found locally."
    echo "Please copy .env.example to .env, populate it, and rerun this script."
fi

echo "Deployment complete."
