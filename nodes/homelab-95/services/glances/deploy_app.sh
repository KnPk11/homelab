#!/bin/bash
# deploy_app.sh — render glances.conf; secrets live under /srv/glances/ only.
#
# Expects:
#   /srv/glances/glances_influx_token.secret  (raw token, one line)
#   /srv/glances/glances.pwd                  (web UI password file; optional at deploy)

set -euo pipefail

SCRIPT_DIR="$(dirname "$(readlink -f "$0")")"
DEST_DIR="/srv/glances"
TOKEN_FILE="$DEST_DIR/glances_influx_token.secret"
PWD_FILE="$DEST_DIR/glances.pwd"

if [[ ! -f "$TOKEN_FILE" ]]; then
    echo "Error: $TOKEN_FILE not found."
    echo "  sudo mkdir -p $DEST_DIR"
    echo "  sudo cp $SCRIPT_DIR/glances_influx_token.secret.example $TOKEN_FILE"
    echo "  sudo chmod 600 $TOKEN_FILE"
    echo "  # put the raw Influx token in that file (no KEY=value)"
    exit 1
fi

# conf template uses ${GLANCES_INFLUX_TOKEN}
export GLANCES_INFLUX_TOKEN
GLANCES_INFLUX_TOKEN="$(tr -d '\n\r' < "$TOKEN_FILE")"

sudo mkdir -p "$DEST_DIR"

echo "Deploying glances.conf to $DEST_DIR/glances.conf..."
envsubst < "$SCRIPT_DIR/glances.conf" | sudo tee "$DEST_DIR/glances.conf" > /dev/null

if [[ ! -f "$PWD_FILE" ]]; then
    echo "Warning: $PWD_FILE missing (web UI password). Compose expects it at that path."
fi

echo "Deployment complete. Secrets stay under $DEST_DIR (not the GitOps clone)."
