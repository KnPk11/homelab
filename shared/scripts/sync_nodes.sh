#!/bin/bash
# =============================================================================
# sync_nodes.sh
# Version: 1.0
# Date: 2026-11-12
#
# Fleet GitOps Synchroniser — triggers on-demand repository pulls across
# homelab nodes from ai-tools over SSH.
#
# Usage:
#   sync_nodes.sh [OPTIONS] <node1> [node2...]
#   sync_nodes.sh [OPTIONS] all
#
# Options:
#   -s, --status   Check current git commit on nodes without pulling.
#   -f, --force    Pass --force to auto_pull_repo.sh (resets dirty working trees).
#   -h, --help     Show this help message.
#
# Examples:
#   sync_nodes.sh ops
#   sync_nodes.sh docker-services k8s lab-vm
#   sync_nodes.sh all
#   sync_nodes.sh --status all
# =============================================================================
set -euo pipefail

# Shared agent env from ai-key-unlock
if [[ -f "${HOME}/.ssh/ai-key-agent.sh" ]]; then
    # shellcheck disable=SC1091
    source "${HOME}/.ssh/ai-key-agent.sh"
fi

ALL_NODES=(
    "ops"
    "docker-services"
    "k8s"
    "lab-vm"
    "scratch-pc"
    "proxmox-host"
    "nas"
    "reverse-proxy"
    "dns"
    "pulse"
    "vpns"
    "pbs"
    "syslog"
)

STATUS_ONLY=false
FORCE_FLAG=""
TARGET_NODES=()

show_help() {
    sed -n '2,20p' "$0" | sed 's/^# //' | sed 's/^#//'
    exit 0
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        -h|--help)
            show_help
            ;;
        -s|--status)
            STATUS_ONLY=true
            shift
            ;;
        -f|--force)
            FORCE_FLAG="--force"
            shift
            ;;
        all)
            TARGET_NODES=("${ALL_NODES[@]}")
            shift
            ;;
        *)
            TARGET_NODES+=("$1")
            shift
            ;;
    esac
done

if [[ ${#TARGET_NODES[@]} -eq 0 ]]; then
    echo "Error: No target nodes specified." >&2
    echo "Usage: $0 [OPTIONS] <node1|all> [node2...]" >&2
    echo "Run '$0 --help' for details." >&2
    exit 1
fi

SSH_OPTS=(-o BatchMode=yes -o ConnectTimeout=5 -o LogLevel=ERROR)

check_status() {
    local node="$1"
    local commit_info
    if ! commit_info=$(ssh "${SSH_OPTS[@]}" "$node" \
        'if [ -d /opt/homelab-repo/.git ]; then git -C /opt/homelab-repo log -1 --format="%h (%cr) - %s"; else echo "NO_REPO"; fi' 2>/dev/null); then
        printf "%-18s [OFFLINE / UNREACHABLE]\n" "$node:"
        return 1
    fi

    if [[ "$commit_info" == "NO_REPO" ]]; then
        printf "%-18s [NO REPO FOUND at /opt/homelab-repo]\n" "$node:"
    else
        printf "%-18s %s\n" "$node:" "$commit_info"
    fi
}

sync_node() {
    local node="$1"
    echo "─── Syncing $node ───"
    
    local remote_cmd="/opt/homelab-repo/shared/scripts/auto_pull_repo.sh $FORCE_FLAG"
    local output
    if ! output=$(ssh "${SSH_OPTS[@]}" "$node" "$remote_cmd" 2>&1); then
        echo "[ERROR] Failed to run sync on $node:" >&2
        echo "$output" >&2
        return 1
    fi
    echo "$output"
}

if [[ "$STATUS_ONLY" == "true" ]]; then
    echo "=== Fleet Repository Status (/opt/homelab-repo) ==="
    for node in "${TARGET_NODES[@]}"; do
        check_status "$node" || true
    done
    echo "==================================================="
    exit 0
fi

echo "Triggering GitOps synchronisation on ${#TARGET_NODES[@]} node(s)..."
FAILED_NODES=()
for node in "${TARGET_NODES[@]}"; do
    if ! sync_node "$node"; then
        FAILED_NODES+=("$node")
    fi
    echo ""
done

if [[ ${#FAILED_NODES[@]} -gt 0 ]]; then
    echo "Sync completed with errors on: ${FAILED_NODES[*]}" >&2
    exit 1
else
    echo "All specified nodes synchronised successfully."
fi
