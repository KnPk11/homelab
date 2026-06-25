#!/usr/bin/env bash
set -e

SCRIPT_DIR="$(dirname "$(readlink -f "$0")")"
ENV_FILE="$SCRIPT_DIR/dozzle.env"
TARGET_DIR="/srv/dozzle"

if [[ ! -f "$ENV_FILE" ]]; then
    echo "Error: $ENV_FILE not found. Please create it from dozzle.env.example."
    exit 1
fi

source "$ENV_FILE"

sudo mkdir -p "$TARGET_DIR"

# Export variables for envsubst
export DOZZLE_USER_EMAIL
export DOZZLE_USER_NAME
export DOZZLE_USER_PASSWORD_HASH

# Use envsubst to deploy users.yml
envsubst '${DOZZLE_USER_EMAIL} ${DOZZLE_USER_NAME} ${DOZZLE_USER_PASSWORD_HASH}' < "$SCRIPT_DIR/users.yml" | sudo tee "$TARGET_DIR/users.yml" > /dev/null



echo "Deployment completed to $TARGET_DIR"
