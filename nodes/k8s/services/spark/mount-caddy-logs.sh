#!/usr/bin/env bash
# =============================================================================
# mount-caddy-logs.sh
# Mount reverse-proxy //logs read-only using systemd LoadCredentialEncrypted.
# Waits for network route and SMB reachability on allow-hotplug DHCP hosts.
# =============================================================================
set -euo pipefail

TARGET="${CADDY_LOGS_MOUNT:-/mnt/caddy-logs}"
SHARE="${CADDY_LOGS_SHARE:-//192.168.50.101/logs}"
WAIT_SECS="${CADDY_LOGS_WAIT_SECS:-45}"
MOUNT_RETRIES="${CADDY_LOGS_MOUNT_RETRIES:-3}"

mkdir -p "$TARGET"

if mountpoint -q "$TARGET"; then
  echo "$TARGET already mounted"
  exit 0
fi

if [[ -z "${CREDENTIALS_DIRECTORY:-}" || ! -f "${CREDENTIALS_DIRECTORY}/smb-logs" ]]; then
  echo "CREDENTIALS_DIRECTORY/smb-logs missing — run via mnt-caddy-logs.service" >&2
  exit 1
fi

extract_smb_host() {
  local host="${1#//}"
  echo "${host%%/*}"
}

wait_for_smb_ready() {
  local host="$1"
  local max_wait="$2"
  local elapsed=0

  [[ -n "$host" ]] || return 0

  while (( elapsed < max_wait )); do
    local target_ip="$host"
    if [[ ! "$host" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
      target_ip="$(getent ahostsv4 "$host" 2>/dev/null | awk 'NR==1 {print $1}')"
    fi

    if [[ -n "$target_ip" ]] \
      && ip -4 route get "$target_ip" 2>/dev/null | grep -q " src " \
      && timeout 2 bash -c "exec 3<>/dev/tcp/${host}/445" >/dev/null 2>&1; then
      return 0
    fi

    sleep 2
    elapsed=$((elapsed + 2))
  done

  echo "Warning: timed out after ${max_wait}s waiting for SMB ${host}:445; attempting mount" >&2
  return 1
}

mount_with_retry() {
  local share="$1"
  local target="$2"
  local opts="$3"
  local attempt=1

  while true; do
    if mount -t cifs "$share" "$target" -o "$opts"; then
      return 0
    fi
    if (( attempt >= MOUNT_RETRIES )); then
      return 1
    fi
    echo "mount attempt ${attempt}/${MOUNT_RETRIES} failed; retrying in 2s..." >&2
    attempt=$((attempt + 1))
    sleep 2
  done
}

smb_host="$(extract_smb_host "$SHARE")"
wait_for_smb_ready "$smb_host" "$WAIT_SECS" || true

# CREDENTIALS_DIRECTORY is an isolated, mode-restricted tmpfs populated by systemd.
cred_src="${CREDENTIALS_DIRECTORY}/smb-logs"
opts="credentials=${cred_src},ro,vers=3.0,uid=0,gid=0,iocharset=utf8,file_mode=0444,dir_mode=0555,noperm,_netdev"

mount_with_retry "$SHARE" "$TARGET" "$opts"
echo "mounted $SHARE -> $TARGET"
mount | grep -F " on ${TARGET} " || true
