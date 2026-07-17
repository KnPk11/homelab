#!/usr/bin/env bash
# =============================================================================
# ai-key-unlock.sh
# Version: 1.2
# Date: 2026-07-16
#
# Unlock passphrase-protected SSH keys into ssh-agent for a limited TTL:
#   - ~/.ssh/id_ed25519_ai  — God Mode (MikroTik / LXCs / VMs)
#   - ~/.ssh/id_ed25519     — Git SSH key / GitHub (if present; was svc_automation)
#
# Same agent, same TTL. Cron watchdog unloads both after expiry.
# Manual unload: ai-key-lock
#
# Usage:
#   ai-key-unlock           # default 2h TTL
#   ai-key-unlock 90        # 90 minutes (bare number = minutes)
#   ai-key-unlock 90m       # same
#   ai-key-unlock 2h        # 2 hours
#   ai-key-unlock 30s       # 30 seconds (explicit s)
#
# Agent env (for other shells / AI tools):
#   source ~/.ssh/ai-key-agent.sh
#
# Override paths (optional):
#   AI_KEY_PATH / AI_GIT_KEY_PATH
# =============================================================================

set -euo pipefail

SCRIPT_DIR="$(dirname "$(readlink -f "$0")")"
# shellcheck disable=SC1091
source "$SCRIPT_DIR/common.sh"

TTL="$(parse_duration_seconds "${1:-}")"
ensure_key_exists
start_agent_if_needed

log "Bundle unlock (TTL $(format_duration "$TTL")):"
while IFS= read -r path; do
  [[ -z "$path" ]] && continue
  log "  - $path ($(key_label "$path"))"
done < <(managed_key_paths)

failed=0
while IFS= read -r path; do
  [[ -z "$path" ]] && continue
  if ! add_key_if_needed "$path"; then
    log "ERROR: ssh-add failed for $path (wrong passphrase or cancelled?)"
    failed=1
  fi
done < <(managed_key_paths)

if (( failed )); then
  # Partial unlock still gets agent env + TTL so remaining keys auto-clear
  write_agent_env
  write_unlock_state "$TTL"
  die "One or more keys failed to load. Partial unlock may still be active — run ai-key-status / ai-key-lock."
fi

write_agent_env
write_unlock_state "$TTL"

left="$(seconds_remaining || true)"
log "Unlocked. Keys auto-unload after $(format_duration "$TTL") (expires in $(format_duration "${left:-$TTL}"))."
log "Scope: lab SSH (God Mode) + GitHub/git when that key is present."
log "When finished early: ai-key-lock"
log "For other shells / Grok:  source $AGENT_ENV_FILE"
ssh-add -l
