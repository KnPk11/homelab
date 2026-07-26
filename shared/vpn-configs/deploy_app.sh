#!/bin/bash
# Description: Deploys the centralised VPN configurations to the host for Portainer to consume.
# Source:       /opt/dev/secrets_vault/vpn-configs (outside repo, not tracked by Git)

set -euo pipefail

SOURCE_DIR="/opt/dev/secrets_vault/vpn-configs"
TARGET_DIR="/srv/vpn-configs"

echo "Deploying VPN configurations to $TARGET_DIR..."

if [ ! -d "$SOURCE_DIR" ]; then
    echo "ERROR: Source directory $SOURCE_DIR not found." >&2
    exit 1
fi

sudo mkdir -p "$TARGET_DIR"
sudo cp -r "$SOURCE_DIR"/. "$TARGET_DIR/"
sudo chmod -R 600 "$TARGET_DIR"

echo "Deployment complete."
