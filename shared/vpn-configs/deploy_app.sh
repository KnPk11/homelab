#!/bin/bash
# Description: Deploys the centralized VPN configurations to the host for Portainer to consume.

TARGET_DIR="/srv/vpn-configs"

echo "Deploying VPN configurations to $TARGET_DIR..."

sudo mkdir -p "$TARGET_DIR"

if [ -d ".secrets" ]; then
    echo "Copying .secrets to $TARGET_DIR/.secrets..."
    sudo cp -r .secrets "$TARGET_DIR/"
    sudo chmod -R 600 "$TARGET_DIR/.secrets"
    echo "Secrets securely deployed."
else
    echo "No .secrets directory found to deploy."
fi

echo "Deployment complete."
