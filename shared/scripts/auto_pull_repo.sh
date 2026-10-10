#!/bin/bash
# =============================================================================
# auto_pull_repo.sh
# Version: 1.5
# Date: 2026-10-10
#
# Hard-reset /opt/homelab-repo, /opt/de-portfolio, and /opt/web-apps to origin/main so nodes
# track GitOps (cron-friendly).
#
# Usage:
#   Run via cron on target nodes (e.g. hourly or daily).
# =============================================================================
set -e

sync_repo() {
    local repo_dir="$1"
    local branch="${2:-main}"

    if [ -d "$repo_dir/.git" ]; then
        echo "[$(date)] Starting auto-pull for $repo_dir ($branch)..."
        cd "$repo_dir" || return 1
        git fetch origin "$branch"
        git reset --hard "origin/$branch"
        echo "[$(date)] Auto-pull complete for $repo_dir."
    fi
}

sync_repo "/opt/homelab-repo" "main"
sync_repo "/opt/de-portfolio" "main"
sync_repo "/opt/web-apps" "main"
