#!/bin/bash
# =============================================================================
# auto_pull_repo.sh
# Version: 1.6
# Date: 2026-10-10
#
# Hard-reset /opt/homelab-repo and /opt/de-portfolio to origin/main so nodes
# track GitOps (cron-friendly).
#
# NOTE ON /opt/web-apps EXCLUSION:
# Web applications (e.g. story-cards, homelab-dashboard) are intentionally NOT
# automatically pulled here. Unlike Airflow DAGs (which hot-reload dynamically
# on disk change) or static infra scripts, web apps run persistent in-memory
# processes that require explicit restarts, virtualenv updates, or database
# migrations. Web apps are deployed via deliberate push/SSH workflows instead.
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
