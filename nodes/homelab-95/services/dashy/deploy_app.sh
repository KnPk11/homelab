#!/bin/bash
# Deploy Dashy Config Template

SCRIPT_DIR="$(dirname "$(readlink -f "$0")")"
ENV_FILE="$SCRIPT_DIR/dashy.env"
TEMPLATE_FILE="$SCRIPT_DIR/config.yml.tmpl"
TARGET_FILE="/srv/dashy/config.yml"

if [ ! -f "$ENV_FILE" ]; then
    echo "Error: Environment file $ENV_FILE not found. Please copy dashy.env.example to dashy.env and fill it out."
    exit 1
fi

if [ ! -f "$TEMPLATE_FILE" ]; then
    echo "Error: Template file $TEMPLATE_FILE not found."
    exit 1
fi

echo "Injecting variables from $ENV_FILE into $TEMPLATE_FILE..."
set -a
source "$ENV_FILE"
set +a

# Use envsubst to replace variables and output directly to the destination path
mkdir -p /srv/dashy
envsubst < "$TEMPLATE_FILE" > "$TARGET_FILE"

echo "Deployment complete! Dashy will automatically hot-reload the changes from $TARGET_FILE."
