#!/bin/bash
# Simple script to template the Privatebin configs using .env variables

if [ ! -f ".env" ]; then
    echo "Error: .env file not found. Please create one from .env.example."
    exit 1
fi

# Load variables from .env
set -a
source .env
set +a

# Destination directory
TARGET_DIR="/srv/privatebin"
mkdir -p "$TARGET_DIR"

# Template conf.php
echo "Templating conf.php..."
envsubst < conf.template.php > "$TARGET_DIR/conf.php"

# Template nginx.conf (even if it currently has no variables, this supports future vars)
echo "Templating nginx.conf..."
# We must carefully escape Nginx variables like $remote_addr or they'll be replaced by envsubst!
# To do this safely, we tell envsubst to ONLY replace $PRIVATEBIN_DOMAIN
envsubst '${PRIVATEBIN_DOMAIN}' < nginx.template.conf > "$TARGET_DIR/nginx.conf"

# Fix permissions for the Privatebin container user (1000:1000)
chown -R 1000:1000 "$TARGET_DIR"

echo "Privatebin configuration deployed to $TARGET_DIR successfully!"
