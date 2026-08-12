#!/usr/bin/env bash
# =============================================================================
# run_mikrotik_insights.sh
# Version: 1.0
# Date: 2026-08-11
#
# Run MikroTik log insights against SMB-mounted reverse-proxy logs.
# =============================================================================
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
JOB="${SCRIPT_DIR}/mikrotik_log_insights.py"
[[ -f /opt/spark/mikrotik_log_insights.py ]] && JOB=/opt/spark/mikrotik_log_insights.py

LOGS_ROOT="${LOGS_ROOT:-/mnt/caddy-logs}"
OUT="${OUT:-/tmp/mikrotik-insights}"
GEO_TOP="${GEO_TOP:-40}"

if [[ ! -d "$LOGS_ROOT/current/mikrotik" && ! -d "$LOGS_ROOT/archive/mikrotik" ]]; then
  echo "No mikrotik dirs under ${LOGS_ROOT}. Start mount: systemctl start mnt-caddy-logs" >&2
  exit 1
fi

mkdir -p "$OUT"
exec python3 "$JOB" \
  --logs-root "$LOGS_ROOT" \
  --output "$OUT" \
  --geo-top "$GEO_TOP" \
  "$@"
