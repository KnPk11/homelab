#!/usr/bin/env bash
# =============================================================================
# ai-key-status.sh
# Version: 1.2
# Date: 2026-07-16
#
# Show whether managed keys (God Mode + GitHub) are loaded and TTL remaining.
# =============================================================================

set -euo pipefail

SCRIPT_DIR="$(dirname "$(readlink -f "$0")")"
# shellcheck disable=SC1091
source "$SCRIPT_DIR/common.sh"

ensure_key_exists
load_agent_env

echo "Bundle:     God Mode lab key + GitHub key (if present)"
echo "Agent env:  $AGENT_ENV_FILE"
echo "State file: $UNLOCK_STATE_FILE"
echo

if agent_alive; then
  echo "Agent:      alive (SSH_AUTH_SOCK=$SSH_AUTH_SOCK)"
else
  echo "Agent:      not connected (run: ai-key-unlock)"
fi

echo "Managed keys:"
while IFS= read -r path; do
  [[ -z "$path" ]] && continue
  if agent_alive && key_loaded "$path"; then
    state="loaded"
  else
    state="not loaded"
  fi
  echo "  [$state] $path ($(key_label "$path"))"
done < <(managed_key_paths)

if [[ ! -f "$GIT_KEY_PATH" ]]; then
  echo "  (no git key at $GIT_KEY_PATH — skipped)"
fi

echo
if read_unlock_state; then
  now="$(date +%s)"
  age=$((now - UNLOCK_TS))
  left=$((TTL_SECONDS - age))
  echo "Unlocked:   $(date -d "@$UNLOCK_TS" '+%Y-%m-%d %H:%M:%S' 2>/dev/null || date -r "$UNLOCK_TS" '+%Y-%m-%d %H:%M:%S')"
  echo "TTL:        $(format_duration "$TTL_SECONDS")"
  if (( left <= 0 )); then
    echo "Remaining:  0 (overdue — watchdog should unload soon)"
  else
    echo "Remaining:  $(format_duration "$left")"
  fi
else
  if any_managed_key_loaded; then
    echo "Unlock state: missing (keys may have been loaded outside ai-key-unlock — no TTL)"
  else
    echo "Unlock state: none"
  fi
fi

echo
echo "Agent identities:"
if agent_alive; then
  ssh-add -l 2>/dev/null || echo "  (none)"
else
  echo "  (agent not connected)"
fi
