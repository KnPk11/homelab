#!/bin/bash
# =============================================================================
# Kopia Repository Initialiser Script
# Version: 1.1
# Date: 2026-07-25
#
# One-time: create the Kopia filesystem repository and local client config.
# Runtime home: /opt/scripts/Backups/Kopia (secrets stay on host, not in Git).
# After create, run: sudo kopia-backup maintenance
#
# Usage:
#   sudo ./initialise_repository.sh
# =============================================================================
set -euo pipefail

CONFIG_DIR="/opt/scripts/Backups/Kopia/config"
CONFIG_FILE="$CONFIG_DIR/main-repo.config"
LOG_DIR="/opt/scripts/Backups/Kopia/logs"
LOG_FILE="$LOG_DIR/backup.log"
REPO_PATH="/mnt/nas/Apps/Kopia/homelab-backup"

if [[ "$EUID" -ne 0 ]]; then
  echo "Run as root (sudo)."
  exit 1
fi

mkdir -p "$CONFIG_DIR" "$LOG_DIR" "$REPO_PATH"
touch "$LOG_FILE"

echo "Creating Kopia repository at $REPO_PATH ..."
echo "Config will be written to $CONFIG_FILE"
kopia repository create filesystem \
  --path="$REPO_PATH" \
  --config-file="$CONFIG_FILE"

chmod 600 "$CONFIG_FILE" "${CONFIG_FILE}.kopia-password" 2>/dev/null || true

echo "Done. Password file (if created): ${CONFIG_FILE}.kopia-password"
echo "Back this directory up via scrape_configs_and_secrets (PATH_SWEEPS includes /opt/scripts/Backups/Kopia)."
