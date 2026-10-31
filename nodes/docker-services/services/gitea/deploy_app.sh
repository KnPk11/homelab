#!/usr/bin/env bash
# =============================================================================
# deploy_app.sh
# Version: 1.0
# Date: 2026-10-31
#
# Decrypt Gitea environment file and provision /srv/gitea/.
#
# Usage:
#   sudo ./deploy_app.sh
# =============================================================================
set -euo pipefail

SCRIPT_DIR="$(dirname "$(readlink -f "$0")")"
TARGET_DIR="/srv/gitea"
ENV_FILE="$SCRIPT_DIR/.env"

if [[ $EUID -ne 0 ]]; then
    exec sudo "$0" "$@"
fi

mkdir -p "$TARGET_DIR"

if [[ -f "$ENV_FILE" ]]; then
    echo "[+] Decrypting .env to $TARGET_DIR/.env..."
    sops -d "$ENV_FILE" > "$TARGET_DIR/.env"
    chmod 600 "$TARGET_DIR/.env"
else
    echo "[!] Warning: $ENV_FILE not found in $SCRIPT_DIR"
fi

chown -R 1000:1000 "$TARGET_DIR"
echo "[+] Gitea environment deployed to $TARGET_DIR successfully!"
