#!/usr/bin/env bash
# =============================================================================
# rollout.sh — web-compromise-watch on hosts that serve HTTP
# Version: 1.0
# Date: 2026-09-02
#
# Default set is not all of inventory.yml — only boxes with a public/lab web
# surface. Override: --hosts a,b,c
# =============================================================================
set -euo pipefail
SCRIPT_DIR="$(dirname "$(readlink -f "$0")")"
REPO="$(cd "$SCRIPT_DIR/../../.." && pwd)"
SSH_CFG="${SSH_CFG:-$REPO/shared/ssh/config}"
REMOTE_DEPLOY="/opt/homelab-repo/shared/observability/web-compromise-watch/deploy.sh"
DEFAULT_HOSTS=(reverse-proxy docker-services lab-vm scratch-pc)

HOSTS=("${DEFAULT_HOSTS[@]}")
if [[ "${1:-}" == "--hosts" ]]; then
  IFS=',' read -r -a HOSTS <<< "${2:-}"
fi

echo "Rollout web-compromise-watch → ${HOSTS[*]}"
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
