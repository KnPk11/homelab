#!/bin/bash
# Template PrivateBin configs using /srv/privatebin/.env (not the GitOps clone)

SCRIPT_DIR="$(dirname "$(readlink -f "$0")")"
ENV_FILE="/srv/privatebin/.env"
TARGET_DIR="/srv/privatebin"

if [ ! -f "$ENV_FILE" ]; then
    echo "Error: $ENV_FILE not found. Copy .env.example there:"
    echo "  sudo mkdir -p $TARGET_DIR"
    echo "  sudo cp $SCRIPT_DIR/.env.example $ENV_FILE"
    echo "  sudo chmod 600 $ENV_FILE"
    exit 1
fi

set -a
# shellcheck source=/dev/null
source "$ENV_FILE"
set +a

mkdir -p "$TARGET_DIR"

echo "Templating conf.php..."
envsubst < "$SCRIPT_DIR/conf.template.php" > "$TARGET_DIR/conf.php"

echo "Templating nginx.conf..."
# Only replace our vars; leave Nginx $remote_addr etc. alone
envsubst '${PRIVATEBIN_DOMAIN}' < "$SCRIPT_DIR/nginx.template.conf" > "$TARGET_DIR/nginx.conf"

chown -R 1000:1000 "$TARGET_DIR"

echo "PrivateBin configuration deployed to $TARGET_DIR successfully!"
