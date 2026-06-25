#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" &> /dev/null && pwd)"
TARGET_DIR="/srv/anytype/data"

echo "--- Deploying Any-Sync Configurations ---"

# 1. Check for .env file
if [ ! -f "$SCRIPT_DIR/.env" ]; then
    echo "ERROR: .env file not found. Please copy .env.example to .env and configure it."
    exit 1
fi

# Source the .env file and export variables for envsubst
set -a
source "$SCRIPT_DIR/.env"
set +a

# 2. Ensure target directory exists
sudo mkdir -p "$TARGET_DIR"

# 3. Render templates
echo "Rendering bundle-config.yml..."
envsubst < "$SCRIPT_DIR/bundle-config.template.yml" | sudo tee "$TARGET_DIR/bundle-config.yml" > /dev/null

echo "Rendering client-config.yml..."
envsubst < "$SCRIPT_DIR/client-config.template.yml" | sudo tee "$TARGET_DIR/client-config.yml" > /dev/null

# 4. Set permissions
sudo chown -R 1000:1000 "$TARGET_DIR"

echo "✅ Configurations deployed successfully to $TARGET_DIR!"
