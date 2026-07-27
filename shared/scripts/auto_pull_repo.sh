#!/bin/bash
# =============================================================================
# auto_pull_repo.sh
# Version: 1.3
# Date: 2026-07-21
#
# Hard-reset /opt/homelab-repo to origin/main so nodes track GitOps (cron-friendly).
#
# Usage:
#   Run via cron on target nodes (e.g. hourly or daily).
# =============================================================================
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

# Note: Repo files are now encrypted in-place with SOPS. 
# Live decrypted runtime files in /srv/ or /opt/scripts/Security receive strict 600 permissions upon deployment.

echo "[$(date)] Auto-pull complete. Repository synced."
