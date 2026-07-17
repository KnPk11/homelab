#!/usr/bin/env bash
# =============================================================================
# ai-key-lock.sh
# Version: 1.2
# Date: 2026-07-16
#
# Unload managed SSH keys from ssh-agent immediately (God Mode + GitHub if
# present). Does not kill ssh-agent.
#
# Usage:
#   ai-key-lock
# =============================================================================

set -euo pipefail

SCRIPT_DIR="$(dirname "$(readlink -f "$0")")"
# shellcheck disable=SC1091
source "$SCRIPT_DIR/common.sh"

ensure_key_exists
load_agent_env

if ! agent_alive; then
  clear_unlock_state
  log "No live ssh-agent (or env missing). Unlock state cleared."
  exit 0
fi

if any_managed_key_loaded; then
  while IFS= read -r path; do
    [[ -z "$path" ]] && continue
    if key_loaded "$path"; then
      unload_key_path "$path"
      log "Unloaded: $path ($(key_label "$path"))"
    fi
  done < <(managed_key_paths)
  clear_unlock_state
else
  clear_unlock_state
  log "No managed keys were loaded. Unlock state cleared."
fi

if agent_alive; then
  log "Remaining identities:"
  ssh-add -l 2>/dev/null || log "(none)"
fi
