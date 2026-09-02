#!/usr/bin/env bash
# =============================================================================
# rollout.sh — install SSH doorbell on every inventory Linux host
# Version: 1.0
# Date: 2026-09-01
#
# Reads inventory.yml (no per-node copies in Git). Run from ai-tools:
#   ./rollout.sh
#   ./rollout.sh --hosts scratch-pc,dns
# =============================================================================
set -euo pipefail
SCRIPT_DIR="$(dirname "$(readlink -f "$0")")"
REPO="$(cd "$SCRIPT_DIR/../../.." && pwd)"
INVENTORY="${INVENTORY:-$REPO/inventory.yml}"
SSH_CFG="${SSH_CFG:-$REPO/shared/ssh/config}"
REMOTE_DEPLOY="/opt/homelab-repo/shared/observability/ssh-doorbell/deploy.sh"

list_nodes() {
  python3 - "$INVENTORY" <<'PY'
import sys
from pathlib import Path
lines = Path(sys.argv[1]).read_text().splitlines()
in_nodes = False
for line in lines:
    if line.startswith("nodes:"):
        in_nodes = True
        continue
    if not in_nodes:
        continue
    if line and not line.startswith(" "):
        break
    if line.startswith("  ") and not line.startswith("    ") and line.rstrip().endswith(":"):
        print(line.strip()[:-1])
PY
}

HOSTS_FILTER=""
if [[ "${1:-}" == "--hosts" ]]; then
  HOSTS_FILTER="${2:-}"
  shift 2 || true
fi

mapfile -t ALL < <(list_nodes)
if [[ -n "$HOSTS_FILTER" ]]; then
  IFS=',' read -r -a WANT <<< "$HOSTS_FILTER"
  HOSTS=()
  for h in "${ALL[@]}"; do
    for w in "${WANT[@]}"; do
      [[ "$h" == "$w" ]] && HOSTS+=("$h")
    done
  done
else
  HOSTS=("${ALL[@]}")
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
