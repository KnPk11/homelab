#!/usr/bin/env bash
# Roll auth-ship to inventory Linux SSH hosts (same set as the SSH doorbell).
set -euo pipefail
SCRIPT_DIR="$(dirname "$(readlink -f "$0")")"
REPO="$(cd "$SCRIPT_DIR/../../.." && pwd)"
SSH_CFG="${SSH_CFG:-$REPO/shared/ssh/config}"
REMOTE_DEPLOY="/opt/homelab-repo/shared/observability/auth-ship/deploy.sh"
DEFAULT_HOSTS=(
  proxmox-host
  docker-services
  nas
  lab-vm
  reverse-proxy
  ai-tools
  dns
  pulse
  vpns
  pbs
  k8s
  scratch-pc
)

HOSTS=("${DEFAULT_HOSTS[@]}")
if [[ "${1:-}" == "--hosts" ]]; then
  IFS=',' read -r -a HOSTS <<< "${2:-}"
fi

echo "Rollout auth-ship → ${HOSTS[*]}"
fail=0
this="$(hostname -s 2>/dev/null || true)"
for h in "${HOSTS[@]}"; do
  echo "----- $h -----"
  if [[ "$h" == "ai-tools" || "$h" == "$this" ]]; then
    if ! "$SCRIPT_DIR/deploy.sh"; then
      echo "FAIL $h (local)"
      fail=$((fail + 1))
    fi
    continue
  fi
  if ssh -F "$SSH_CFG" -o BatchMode=yes -o ConnectTimeout=8 "$h" \
    "test -x $REMOTE_DEPLOY && $REMOTE_DEPLOY"; then
    echo "OK $h"
  else
    echo "FAIL $h"
    fail=$((fail + 1))
  fi
done
if [[ "$fail" -ne 0 ]]; then
  echo "Finished with $fail failure(s)"
  exit 1
fi
echo "Finished OK"
