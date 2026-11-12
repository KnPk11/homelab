#!/bin/bash
# =============================================================================
# deploy_app.sh
# Version: 1.1
# Date: 2026-07-26
#
# Copy centralised VPN profiles from secrets_vault into /srv/vpn-configs
# for Portainer/consumers (source tree is outside Git).
#
# Usage:
#   sudo ./deploy_app.sh
# =============================================================================
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
