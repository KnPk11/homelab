#!/usr/bin/env bash
# =============================================================================
# ai-key-ttl-watchdog.sh
# Version: 1.2
# Date: 2026-07-16
#
# Cron watchdog: if the key bundle has been unlocked longer than its TTL
# (default 2h from unlock), unload all managed keys from ssh-agent.
#
# Cron (every 5 minutes on ai-tools-105):
#   */5 * * * * /opt/dev/homelab_repo/nodes/ai-tools-105/services/ai-ssh-key/ai-key-ttl-watchdog.sh >> /var/log/ai-key-ttl.log 2>&1
# =============================================================================

set -euo pipefail

SCRIPT_DIR="$(dirname "$(readlink -f "$0")")"
# shellcheck disable=SC1091
source "$SCRIPT_DIR/common.sh"

if ! read_unlock_state; then
  exit 0
fi

load_agent_env

if ! agent_alive; then
  log "Agent not reachable; clearing unlock state"
  clear_unlock_state
  exit 0
fi

if ! any_managed_key_loaded; then
  log "No managed keys loaded; clearing unlock state"
  clear_unlock_state
  exit 0
fi

now="$(date +%s)"
age=$((now - UNLOCK_TS))
left=$((TTL_SECONDS - age))

if (( left > 0 )); then
  exit 0
fi

log "TTL expired (age $(format_duration "$age") >= $(format_duration "$TTL_SECONDS")); unloading managed keys"
unload_key

if any_managed_key_loaded; then
  log "WARNING: one or more managed keys still present after unload attempt"
  exit 1
fi

log "Managed keys unloaded successfully"
exit 0
