#!/bin/bash
# Description: Automatically pulls the latest configuration from the GitOps repository.
# Usage: Run via cron on target nodes (e.g., hourly or daily).

REPO_DIR="/opt/homelab-repo"

if [ ! -d "$REPO_DIR/.git" ]; then
    echo "Error: Git repository not found at $REPO_DIR"
    exit 1
fi

echo "[$(date)] Starting auto-pull for $REPO_DIR..."

cd "$REPO_DIR" || exit 1

# Fetch the latest changes from the remote
git fetch origin main

# Hard reset to exactly match the remote, discarding any accidental local changes on the server
git reset --hard origin/main

# Secure all un-tracked local .env files that may exist in this repository
# NOTE: We explicitly exclude specific secrets that break if they are set to 600.
# Known legacy exceptions requiring 644: glances.pwd, mediamtx_password, nextcloud_hpb_secrets.env
find "$REPO_DIR" -type f -name "*.env" ! -name "nextcloud_hpb_secrets.env" -exec chmod 600 {} + 2>/dev/null || true

echo "[$(date)] Auto-pull complete. Repository synced and local secrets secured."
