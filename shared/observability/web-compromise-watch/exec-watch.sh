#!/usr/bin/env bash
# Poll /proc for unexpected execs (shells / reverse-shell binaries).
# Unprivileged LXCs cannot run auditd; this is the portable doorbell.
set -euo pipefail

ENV_FILE="${EXEC_WATCH_ENV:-/srv/web-compromise-watch/exec-watch.env}"
if [[ -f "$ENV_FILE" ]]; then
  # shellcheck source=/dev/null
  set -a
  . "$ENV_FILE"
  set +a
fi

INTERVAL="${INTERVAL:-5}"
HOST="$(hostname -s)"
SEND="${TELEGRAM_SEND:-/usr/local/sbin/homelab-watch-send}"
STATE_DIR="${STATE_DIR:-/run/web-compromise-watch}"
mkdir -p "$STATE_DIR"

IFS=',' read -r -a COMM_ARR <<< "${WATCH_COMMS:-sh,bash,dash,nc,ncat,netcat,socat}"
IFS=',' read -r -a UID_ARR <<< "${WATCH_UIDS:-}"
CGROUP_REGEX="${WATCH_CGROUP_REGEX:-}"
RATE_SEC="${RATE_SEC:-60}"

if [[ ${#COMM_ARR[@]} -eq 0 ]]; then
  echo "exec-watch: WATCH_COMMS is empty" >&2
  exit 1
fi
if [[ -z "$CGROUP_REGEX" && -z "${WATCH_UIDS:-}" && "${ALLOW_ANY_UID:-}" != "1" ]]; then
  echo "exec-watch: set WATCH_UIDS, WATCH_CGROUP_REGEX, or ALLOW_ANY_UID=1" >&2
  exit 1
fi

declare -A COMM_OK=()
for c in "${COMM_ARR[@]}"; do
  c="${c// /}"
  [[ -n "$c" ]] && COMM_OK["$c"]=1
done
declare -A UID_OK=()
for u in "${UID_ARR[@]}"; do
  u="${u// /}"
  [[ -n "$u" ]] && UID_OK["$u"]=1
done

in_list() { [[ -n "${COMM_OK[$1]:-}" ]]; }

match_uid() {
  local uid="$1"
  [[ ${#UID_OK[@]} -eq 0 ]] && return 0
  [[ -n "${UID_OK[$uid]:-}" ]]
}

match_cgroup() {
  local file="$1"
  [[ -z "$CGROUP_REGEX" ]] && return 0
  [[ -r "$file" ]] && grep -Eq "$CGROUP_REGEX" "$file"
}

scan() {
  local pid uid comm cg now last
  now="$(date +%s)"
  for proc in /proc/[0-9]*; do
    pid="${proc#/proc/}"
    [[ -r "$proc/comm" && -r "$proc/status" ]] || continue
    comm="$(tr -d '\n' < "$proc/comm" 2>/dev/null || true)"
    in_list "$comm" || continue
    uid="$(awk '/^Uid:/{print $2; exit}' "$proc/status" 2>/dev/null || true)"
    [[ -n "$uid" ]] || continue
    match_uid "$uid" || continue
    match_cgroup "$proc/cgroup" || continue
    last="${STATE_DIR}/${comm}.${uid}.${pid}"
    if [[ -f "$last" ]]; then
      continue
    fi
    # Rate-limit identical comm+uid bursts (fork loops).
    if [[ -f "${STATE_DIR}/rate.${comm}.${uid}" ]]; then
      if (( now - $(cat "${STATE_DIR}/rate.${comm}.${uid}") < RATE_SEC )); then
        continue
      fi
    fi
    echo "$now" > "$last"
    echo "$now" > "${STATE_DIR}/rate.${comm}.${uid}"
    "$SEND" "🐚 web-compromise ${HOST}: uid=${uid} pid=${pid} comm=${comm}" || true
  done
  # Drop state for pids that exited.
  for f in "$STATE_DIR"/*; do
    [[ -f "$f" ]] || continue
    base="$(basename "$f")"
    [[ "$base" == rate.* ]] && continue
    pid="${base##*.}"
    [[ -d "/proc/$pid" ]] || rm -f "$f"
  done
}

while true; do
  scan || true
  sleep "$INTERVAL"
done
