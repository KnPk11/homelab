#!/bin/bash
# =============================================================================
# deploy-app.sh
# Version: 1.1
# Date: 2026-11-13
#
# Template Nextcloud config.php (and related files) using /srv/nextcloud/.env.
#
# Usage:
#   sudo ./deploy-app.sh
# =============================================================================
set -euo pipefail

SCRIPT_DIR="$(dirname "$(readlink -f "$0")")"
ENV_FILE="/srv/nextcloud/.env"

if [ ! -f "$ENV_FILE" ]; then
    echo "Error: $ENV_FILE not found. Copy .env.example there and configure it:"
    echo "  sudo mkdir -p /srv/nextcloud"
    echo "  sudo cp $SCRIPT_DIR/.env.example $ENV_FILE"
    echo "  sudo chmod 600 $ENV_FILE"
    exit 1
fi

# Load variables from host-local .env (not the GitOps clone)
set -a
# shellcheck source=/dev/null
source "$ENV_FILE"
set +a

# Destination directory
TARGET_DIR="/srv/nextcloud/config"
mkdir -p "$TARGET_DIR"

# Template config.php
echo "Templating config.php..."
# Substitute ONLY the variables we need, avoiding PHP's own $variables like $CONFIG
envsubst '${NC_DOMAIN} ${TALK_HOST} ${NC_INSTANCEID} ${NC_PASSWORDSALT} ${NC_SECRET} ${NC_DBPASSWORD}' < "$SCRIPT_DIR/config.template.php" > "$TARGET_DIR/config.php"

# Copy apache2.conf
echo "Deploying apache2.conf..."
cp "$SCRIPT_DIR/apache2.conf" "$TARGET_DIR/apache2.conf"

# Ensure correct ownership for Nextcloud container
# Note: Nextcloud usually runs as www-data (uid 33) in the official image
chown -R 33:33 "$TARGET_DIR"

echo "Nextcloud configuration deployed to $TARGET_DIR successfully!"
