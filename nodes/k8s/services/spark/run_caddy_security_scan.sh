#!/usr/bin/env bash
# =============================================================================
# run_caddy_security_scan.sh
# Version: 1.0
# Date: 2026-08-11
#
# Stage Caddy (current + archive) + Fail2Ban + CrowdSec + MikroTik logs,
# then run full-accuracy geo security scan.
#
# Preferred input layout (reverse-proxy /mnt/logs or a staged copy):
#   LOGS_ROOT/
#     current/{caddy,fail2ban,crowdsec,mikrotik}/
#     archive/{caddy,fail2ban,crowdsec,mikrotik}/   # *.log.gz streamed, not unpacked
#
# Usage:
#   ./run_caddy_security_scan.sh
#   ./run_caddy_security_scan.sh --skip-stage
#   LOGS_ROOT=/mnt/logs ./run_caddy_security_scan.sh --skip-stage   # SMB mount
#   ./run_caddy_security_scan.sh --skip-geo
# =============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
JOB="${SCRIPT_DIR}/caddy_security_scan.py"
[[ -f /opt/spark/caddy_security_scan.py ]] && JOB=/opt/spark/caddy_security_scan.py

SSH_CFG="${SSH_CFG:-/opt/homelab-repo/shared/ssh/config}"
[[ -f "$SSH_CFG" ]] || SSH_CFG=/opt/dev/homelab_repo/shared/ssh/config

REVERSE_PROXY="${REVERSE_PROXY:-reverse-proxy}"
# Staged reverse-proxy-style tree (current + archive)
STAGE_ROOT="${STAGE_ROOT:-/srv/spark/logs-root}"
OUT="${OUT:-/tmp/caddy-sec-out}"
# If set, use this path as --logs-root (e.g. live SMB mount) and skip rsync
LOGS_ROOT="${LOGS_ROOT:-}"

SKIP_STAGE=0
SKIP_GEO=0
SKIP_MIKROTIK=0
while [[ $# -gt 0 ]]; do
  case "$1" in
    --skip-stage) SKIP_STAGE=1; shift ;;
    --skip-geo) SKIP_GEO=1; shift ;;
    --skip-mikrotik) SKIP_MIKROTIK=1; shift ;;
    -h|--help)
      echo "Usage: $0 [--skip-stage] [--skip-geo] [--skip-mikrotik]"
      echo "  STAGE_ROOT=/srv/spark/logs-root   staged current+archive tree (prefer SMB LOGS_ROOT)"
      echo "  LOGS_ROOT=/mnt/logs               live mount (implies use as --logs-root)"
      echo "  OUT=/tmp/caddy-sec-out"
      exit 0
      ;;
    *) echo "Unknown: $1" >&2; exit 1 ;;
  esac
done

stage_from_proxy() {
  local dest="$1"
  echo "[stage] rsync current+archive (caddy/fail2ban/crowdsec/mikrotik) from ${REVERSE_PROXY}:/mnt/logs → ${dest}"
  mkdir -p "$dest"
  local rsync_e=(rsync -az --no-owner --no-group)
  if [[ -f "$SSH_CFG" ]]; then
    rsync_e+=(-e "ssh -F ${SSH_CFG} -o BatchMode=yes -o ConnectTimeout=15")
  fi
  # Pull only security-relevant trees; keep rotated .gz; skip giant snapshot tars
  "${rsync_e[@]}" \
    --include='current/' \
    --include='archive/' \
    --include='current/caddy/***' \
    --include='archive/caddy/***' \
    --include='current/fail2ban/***' \
    --include='archive/fail2ban/***' \
    --include='current/crowdsec/***' \
    --include='archive/crowdsec/***' \
    --include='current/mikrotik/***' \
    --include='archive/mikrotik/***' \
    --exclude='*.tar.gz' \
    --exclude='*.tgz' \
    --exclude='*' \
    "${REVERSE_PROXY}:/mnt/logs/" "${dest}/" || {
      echo "[stage] rsync failed (often: reverse-proxy SSH blocked from this host)." >&2
      echo "        Stage via ai-tools, or mount SMB and set LOGS_ROOT=/mnt/logs --skip-stage." >&2
      return 1
    }
  echo "[stage] $(find "$dest" -type f | wc -l) files, $(du -sh "$dest" | awk '{print $1}')"
}

ROOT_ARG=()
if [[ -n "$LOGS_ROOT" ]]; then
  ROOT_ARG=(--logs-root "$LOGS_ROOT")
  echo "[input] LOGS_ROOT=${LOGS_ROOT}"
elif [[ "$SKIP_STAGE" -eq 0 ]]; then
  stage_from_proxy "$STAGE_ROOT"
  ROOT_ARG=(--logs-root "$STAGE_ROOT")
elif [[ -d "$STAGE_ROOT/current" || -d "$STAGE_ROOT/archive" ]]; then
  ROOT_ARG=(--logs-root "$STAGE_ROOT")
  echo "[stage] skipped — using existing ${STAGE_ROOT}"
else
  # Legacy flat paths (current-only caddy stage)
  echo "[stage] skipped — prefer LOGS_ROOT=/mnt/caddy-logs (SMB) when available"
  ROOT_ARG=()
fi

mkdir -p "$OUT"
EXTRA=()
[[ "$SKIP_GEO" -eq 1 ]] && EXTRA+=(--skip-geo)
[[ "$SKIP_MIKROTIK" -eq 1 ]] && EXTRA+=(--skip-mikrotik)

exec python3 "$JOB" \
  "${ROOT_ARG[@]}" \
  --geo-cache "${GEO_CACHE:-/srv/spark/geocode/geocode_findings.json}" \
  --output "$OUT" \
  --min-denied 5 \
  --min-mt-drops 5 \
  "${EXTRA[@]}"
