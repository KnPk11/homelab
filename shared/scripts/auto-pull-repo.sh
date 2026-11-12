#!/bin/bash
# =============================================================================
# auto-pull-repo.sh
# Version: 2.0
# Date: 2026-11-12
#
# Safely synchronises /opt/homelab-repo and /opt/de-portfolio with origin/main.
# Protects against silent data loss:
#   - Verifies the working tree is clean before pulling.
#   - Uses non-destructive fast-forward merge (--ff-only) by default.
#   - Skips pulling if local uncommitted changes exist.
#   - Automatically excludes authoring nodes (e.g. ai-tools).
#
# Options:
#   --force    Force reset to origin/main even if local changes exist.
# =============================================================================
set -euo pipefail

FORCE=false
for arg in "$@"; do
    case "$arg" in
        --force|-f)
            FORCE=true
            ;;
    esac
done

# Guard against running on authoring nodes
if [[ "$(hostname)" == "ai-tools" ]]; then
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [SKIP] ai-tools is an authoring node. Automatic pull disabled."
    exit 0
fi

sync_repo() {
    local repo_dir="$1"
    local branch="${2:-main}"

    if [[ ! -d "$repo_dir/.git" ]]; then
        return 0
    fi

    cd "$repo_dir" || return 1

    # Check for dirty working tree (ignoring untracked files)
    if [[ -n "$(git status --porcelain -uno)" ]] && [[ "$FORCE" != "true" ]]; then
        echo "[$(date '+%Y-%m-%d %H:%M:%S')] [WARN] Uncommitted changes detected in $repo_dir on $(hostname). Skipping sync to prevent data loss."
        return 0
    fi

    # Fetch latest remote state
    git fetch origin "$branch" --quiet

    local local_sha remote_sha
    local_sha=$(git rev-parse HEAD)
    remote_sha=$(git rev-parse "origin/$branch")

    if [[ "$local_sha" == "$remote_sha" ]]; then
        echo "[$(date '+%Y-%m-%d %H:%M:%S')] [OK] $repo_dir on $(hostname) is already up to date (${local_sha:0:7})."
        return 0
    fi

    if [[ "$FORCE" == "true" ]]; then
        git reset --hard "origin/$branch"
        echo "[$(date '+%Y-%m-%d %H:%M:%S')] [RESET] $repo_dir on $(hostname) force-reset to origin/$branch (${remote_sha:0:7})."
    else
        if git merge --ff-only "origin/$branch" >/dev/null 2>&1; then
            echo "[$(date '+%Y-%m-%d %H:%M:%S')] [SYNC] $repo_dir on $(hostname) fast-forwarded: ${local_sha:0:7} -> ${remote_sha:0:7}."
        else
            echo "[$(date '+%Y-%m-%d %H:%M:%S')] [ERROR] Divergence in $repo_dir on $(hostname). Fast-forward not possible. Skipping."
            return 1
        fi
    fi
}

sync_repo "/opt/homelab-repo" "main"
sync_repo "/opt/de-portfolio" "main"

