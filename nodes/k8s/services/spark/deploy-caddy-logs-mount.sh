#!/usr/bin/env bash
# =============================================================================
# deploy-caddy-logs-mount.sh
# Install mnt-caddy-logs.service and /usr/local/sbin/mount-caddy-logs.sh
# onto a Spark worker node (e.g. lab-vm or scratch-pc).
#
# Usage:
#   ./deploy-caddy-logs-mount.sh              # install files and reload systemd
#   ./deploy-caddy-logs-mount.sh --enable     # install and enable --now
#   ./deploy-caddy-logs-mount.sh --disable    # install and disable --now
# =============================================================================
set -euo pipefail

SCRIPT_DIR="$(dirname "$(readlink -f "$0")")"
CREDSTORE_PATH="/etc/credstore.encrypted/smb-logs"
ACTION="install"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --enable)  ACTION="enable"; shift ;;
    --disable) ACTION="disable"; shift ;;
    -h|--help)
      sed -n '2,12p' "$0" | sed 's/^# //' | sed 's/^#//'
      exit 0
      ;;
    *)
      echo "Unknown option: $1" >&2
      echo "Usage: $0 [--enable|--disable]" >&2
      exit 2
      ;;
  esac
done

mountpoint -q /mnt/caddy-logs || mkdir -p /mnt/caddy-logs
install -m 755 "${SCRIPT_DIR}/mount-caddy-logs.sh" /usr/local/sbin/mount-caddy-logs.sh
install -m 644 "${SCRIPT_DIR}/mnt-caddy-logs.service" /etc/systemd/system/mnt-caddy-logs.service
systemctl daemon-reload

if [[ ! -f "$CREDSTORE_PATH" ]]; then
  echo "Note: ${CREDSTORE_PATH} does not exist on $(hostname -s)." >&2
  echo "Create it once with systemd-creds encrypt (--name=smb-logs) before enabling." >&2
fi

case "$ACTION" in
  enable)
    systemctl reset-failed mnt-caddy-logs.service >/dev/null 2>&1 || true
    systemctl enable --now mnt-caddy-logs.service
    ;;
  disable)
    systemctl disable --now mnt-caddy-logs.service
    systemctl reset-failed mnt-caddy-logs.service >/dev/null 2>&1 || true
    ;;
  install)
    echo "Installed mnt-caddy-logs unit and mount helper on $(hostname -s) (unit state unchanged)."
    ;;
esac
