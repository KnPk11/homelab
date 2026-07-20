# Shared helpers for God Mode AI + Git SSH key TTL tooling.
# Sourced by unlock / lock / watchdog scripts — not executed directly.
#
# Keys managed as a bundle (same agent + same TTL):
#   1) ~/.ssh/id_ed25519_ai  — privileged lab SSH (MikroTik, LXCs, VMs)
#   2) ~/.ssh/id_ed25519     — Git SSH key for GitHub (optional if file exists)
#
# Agent env path must NOT end in ".env" (sandbox deny lists often stub **/*.env).

# shellcheck shell=bash

# Primary (God Mode) — required
KEY_PATH="${AI_KEY_PATH:-$HOME/.ssh/id_ed25519_ai}"
# Secondary (GitHub) — unlocked/locked with the same TTL when present
GIT_KEY_PATH="${AI_GIT_KEY_PATH:-$HOME/.ssh/id_ed25519}"
AGENT_ENV_FILE="${AI_KEY_AGENT_ENV:-$HOME/.ssh/ai-key-agent.sh}"
UNLOCK_STATE_FILE="${AI_KEY_UNLOCK_STATE:-$HOME/.ssh/ai-key-unlock.state}"
DEFAULT_TTL_SECONDS="${AI_KEY_TTL_SECONDS:-7200}" # 2 hours

log() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*"; }

die() { log "ERROR: $*"; exit 1; }

ensure_key_exists() {
  [[ -f "$KEY_PATH" ]] || die "SSH key not found: $KEY_PATH"
  [[ -f "${KEY_PATH}.pub" ]] || die "Public key not found: ${KEY_PATH}.pub"
}

# Print managed private key paths (one per line). Git key only if present and distinct.
managed_key_paths() {
  printf '%s\n' "$KEY_PATH"
  if [[ -n "${GIT_KEY_PATH:-}" && -f "$GIT_KEY_PATH" && "$GIT_KEY_PATH" != "$KEY_PATH" ]]; then
    printf '%s\n' "$GIT_KEY_PATH"
  fi
}

key_label() {
  case "$1" in
    *id_ed25519_ai) echo "God Mode (lab)" ;;
    *id_ed25519)    echo "Git SSH (GitHub)" ;;
    *)              echo "SSH key" ;;
  esac
}

_file_usable() {
  # Non-empty and readable (skip empty sandbox stubs)
  [[ -f "$1" && -s "$1" && -r "$1" ]]
}

write_agent_env() {
  umask 077
  if ! printf 'export SSH_AUTH_SOCK=%q\nexport SSH_AGENT_PID=%q\n' \
    "$SSH_AUTH_SOCK" "$SSH_AGENT_PID" >"$AGENT_ENV_FILE" 2>/dev/null; then
    die "Cannot write agent env to $AGENT_ENV_FILE (permission/sandbox?)"
  fi
  chmod 600 "$AGENT_ENV_FILE" 2>/dev/null || true
}

load_agent_env() {
  # Always return 0: "no agent" is a normal state (status/lock must still print).
  # With set -e, a failing last command in this function would abort callers silently.
  if _file_usable "$AGENT_ENV_FILE"; then
    # shellcheck disable=SC1090
    source "$AGENT_ENV_FILE"
    if agent_alive; then
      return 0
    fi
    # Stale env file (agent died / rebooted) — ignore sock and keep looking
    unset SSH_AUTH_SOCK SSH_AGENT_PID || true
  fi
  # Last resort: find a live agent that already has the God Mode key
  discover_agent_with_key || true
  return 0
}

agent_alive() {
  [[ -n "${SSH_AUTH_SOCK:-}" && -S "${SSH_AUTH_SOCK}" ]] || return 1
  # ssh-add -l exits 1 if no identities, 2 if cannot connect
  local rc=0
  ssh-add -l >/dev/null 2>&1 || rc=$?
  [[ $rc -eq 0 || $rc -eq 1 ]]
}

_key_fingerprint() {
  local path="$1"
  ssh-keygen -lf "${path}.pub" 2>/dev/null | awk '{print $2}'
}

# key_loaded [path] — default: God Mode KEY_PATH
key_loaded() {
  local path="${1:-$KEY_PATH}"
  agent_alive || return 1
  ssh-add -l 2>/dev/null | grep -qF "$path" && return 0
  local pub
  pub="$(_key_fingerprint "$path")"
  [[ -n "$pub" ]] && ssh-add -l 2>/dev/null | grep -qF "$pub"
}

# True if every managed key that exists on disk is loaded
all_managed_keys_loaded() {
  local path
  while IFS= read -r path; do
    [[ -z "$path" ]] && continue
    key_loaded "$path" || return 1
  done < <(managed_key_paths)
  return 0
}

# True if any managed key is loaded
any_managed_key_loaded() {
  local path
  while IFS= read -r path; do
    [[ -z "$path" ]] && continue
    key_loaded "$path" && return 0
  done < <(managed_key_paths)
  return 1
}

discover_agent_with_key() {
  local sock pub path
  path="$KEY_PATH"
  pub="$(_key_fingerprint "$path")"
  [[ -n "$pub" ]] || return 1
  shopt -s nullglob
  for sock in /tmp/ssh-*/agent.*; do
    [[ -S "$sock" ]] || continue
    if SSH_AUTH_SOCK="$sock" ssh-add -l 2>/dev/null | grep -qF "$pub"; then
      export SSH_AUTH_SOCK="$sock"
      return 0
    fi
  done
  return 1
}

start_agent_if_needed() {
  if agent_alive; then
    return 0
  fi
  load_agent_env
  if agent_alive; then
    return 0
  fi
  eval "$(ssh-agent -s)" >/dev/null
  write_agent_env
}

write_unlock_state() {
  local ttl="$1"
  local now
  now="$(date +%s)"
  umask 077
  cat >"$UNLOCK_STATE_FILE" <<EOF
UNLOCK_TS=${now}
TTL_SECONDS=${ttl}
KEY_PATH=${KEY_PATH}
GIT_KEY_PATH=${GIT_KEY_PATH}
EOF
  chmod 600 "$UNLOCK_STATE_FILE"
}

clear_unlock_state() {
  rm -f "$UNLOCK_STATE_FILE"
}

read_unlock_state() {
  UNLOCK_TS=""
  TTL_SECONDS="$DEFAULT_TTL_SECONDS"
  [[ -f "$UNLOCK_STATE_FILE" ]] || return 1
  # shellcheck disable=SC1090
  source "$UNLOCK_STATE_FILE"
  [[ -n "${UNLOCK_TS:-}" ]]
}

# Parse duration → seconds.
# Bare number = minutes (e.g. 90 → 90m). Suffixes: 2h | 90m | 30s
parse_duration_seconds() {
  local raw="${1:-}"
  if [[ -z "$raw" ]]; then
    echo "$DEFAULT_TTL_SECONDS"
    return
  fi
  if [[ "$raw" =~ ^([0-9]+)([HhMmSs])?$ ]]; then
    local n="${BASH_REMATCH[1]}"
    local u="${BASH_REMATCH[2]:-m}" # default unit: minutes
    case "$u" in
      [Hh]) echo $((n * 3600)) ;;
      [Mm]|'') echo $((n * 60)) ;;
      [Ss]) echo "$n" ;;
    esac
    return
  fi
  die "Invalid duration '$raw' (use e.g. 90, 90m, 2h, 30s — bare number is minutes)"
}

# unload_key_path path
unload_key_path() {
  local path="$1"
  agent_alive || return 0
  if key_loaded "$path"; then
    ssh-add -d "$path" 2>/dev/null \
      || ssh-add -d "${path}.pub" 2>/dev/null \
      || true
  fi
}

# Unload all managed keys and clear TTL state
unload_key() {
  load_agent_env
  if ! agent_alive; then
    clear_unlock_state
    return 0
  fi
  local path
  while IFS= read -r path; do
    [[ -z "$path" ]] && continue
    unload_key_path "$path"
  done < <(managed_key_paths)
  clear_unlock_state
}

# ssh-add one key if not already loaded; returns 0 if loaded (already or newly)
add_key_if_needed() {
  local path="$1"
  local label
  label="$(key_label "$path")"
  if key_loaded "$path"; then
    log "Already loaded: $path ($label)"
    return 0
  fi
  log "Adding $path ($label)..."
  log "Enter the passphrase when prompted."
  if ! ssh-add "$path"; then
    return 1
  fi
  return 0
}

seconds_remaining() {
  read_unlock_state || { echo 0; return 1; }
  local now age left
  now="$(date +%s)"
  age=$((now - UNLOCK_TS))
  left=$((TTL_SECONDS - age))
  if (( left < 0 )); then
    echo 0
  else
    echo "$left"
  fi
}

format_duration() {
  local s="$1"
  local h=$((s / 3600))
  local m=$(((s % 3600) / 60))
  local r=$((s % 60))
  if (( h > 0 )); then
    printf '%dh%02dm' "$h" "$m"
  elif (( m > 0 )); then
    printf '%dm%02ds' "$m" "$r"
  else
    printf '%ds' "$s"
  fi
}
