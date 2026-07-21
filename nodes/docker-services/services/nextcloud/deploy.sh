#!/bin/bash
# Simple script to template the Nextcloud config.php using .env variables

if [ ! -f ".env" ]; then
    echo "Error: .env file not found. Please create one from .env.example."
    exit 1
fi

# Load variables from .env
set -a
source .env
set +a

# Destination directory
TARGET_DIR="/srv/nextcloud/config"
mkdir -p "$TARGET_DIR"

# Template config.php
echo "Templating config.php..."
# Substitute ONLY the variables we need, avoiding PHP's own $variables like $CONFIG
envsubst '${NC_DOMAIN} ${TALK_HOST} ${NC_INSTANCEID} ${NC_PASSWORDSALT} ${NC_SECRET} ${NC_DBPASSWORD}' < config.template.php > "$TARGET_DIR/config.php"

# Copy apache2.conf
echo "Deploying apache2.conf..."
cp apache2.conf "$TARGET_DIR/apache2.conf"

# Ensure correct ownership for Nextcloud container
# Note: Nextcloud usually runs as www-data (uid 33) in the official image
chown -R 33:33 "$TARGET_DIR"

echo "Nextcloud configuration deployed to $TARGET_DIR successfully!"
