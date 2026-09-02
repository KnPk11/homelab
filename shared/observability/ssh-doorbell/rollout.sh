#!/usr/bin/env bash
# =============================================================================
# rollout.sh — install SSH doorbell on every inventory Linux host
# Version: 1.0
# Date: 2026-09-01
#
# Host list is DEFAULT_HOSTS below (no per-node copies in Git). Run from ai-tools:
#   ./rollout.sh
#   ./rollout.sh --hosts scratch-pc,dns
# =============================================================================
set -euo pipefail
SCRIPT_DIR="$(dirname "$(readlink -f "$0")")"
REPO="$(cd "$SCRIPT_DIR/../../.." && pwd)"
SSH_CFG="${SSH_CFG:-$REPO/shared/ssh/config}"
REMOTE_DEPLOY="/opt/homelab-repo/shared/observability/ssh-doorbell/deploy.sh"

# Every inventory Linux SSH host (skip Windows). Keep in sync with inventory.yml.
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
  shift 2 || true
fi

echo "Rollout SSH doorbell → ${HOSTS[*]}"
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
  if ssh -F "$SSH_CFG" -o BatchMode=yes -o ConnectTimeout=8 "$h" "test -x $REMOTE_DEPLOY && $REMOTE_DEPLOY"; then
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
