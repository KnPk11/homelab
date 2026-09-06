#!/usr/bin/env bash
# Every-other-Sunday Homelab Watch nudge. No SSH, no God Mode, no model.
set -euo pipefail
ENV_FILE="${TELEGRAM_ENV:-/etc/ssh/telegram.env}"
[[ -s "$ENV_FILE" ]] || ENV_FILE=/srv/homelab-watch/telegram.env
STAMP="${REMINDER_STAMP:-/var/lib/monthly-audit/last-reminder}"
MIN_GAP_DAYS="${REMINDER_GAP_DAYS:-13}"
DRY_RUN=0
FORCE=0
[[ "${1:-}" == "--dry-run" ]] && DRY_RUN=1
[[ "${1:-}" == "--force" ]] && FORCE=1

text='📋 Audit due

This is a nudge only. Nothing was scanned.

Unlock God Mode on ai-tools:

  ai-key-unlock && source ~/.ssh/ai-key-agent.sh

Then pick a depth:

LIGHT
  monthly-audit --light
  CrowdSec, Caddy, DSTNAT, key status, reboot flags, updates
  No Lynis / Docker Bench

DEEP
  monthly-audit --deep
  Everything in light, plus Lynis on guests and Docker Bench on docker-services

After the snapshot, God Mode locks before Grok runs. The digest lands here:

  FIX NOW / TRACK / NEEDS BASELINE UPDATE / ACCEPTED

Empty buckets stay so a quiet run is still visible. Skip this if last Sunday'\''s sweep is still 🔴.'

if [[ "$DRY_RUN" -eq 1 ]]; then
  printf '%s\n' "$text"
  exit 0
fi

if [[ "$FORCE" -ne 1 && -f "$STAMP" ]]; then
  last=$(stat -c %Y "$STAMP" 2>/dev/null || echo 0)
  now=$(date +%s)
  gap=$((MIN_GAP_DAYS * 86400))
  if (( now - last < gap )); then
    echo "monthly-audit-reminder: skip (last send $(( (now - last) / 86400 ))d ago)"
    exit 0
  fi
fi

# shellcheck source=/dev/null
set -a
[[ -r "$ENV_FILE" ]] && . "$ENV_FILE"
set +a
token="${BOT_TOKEN:-${TELEGRAM_BOT_TOKEN:-}}"
chat="${CHAT_ID:-${TELEGRAM_CHAT_ID:-}}"
if [[ -z "$token" || -z "$chat" ]]; then
  echo "monthly-audit-reminder: missing telegram env" >&2
  exit 1
fi
python3 - "$token" "$chat" "$text" <<'PY'
import sys, urllib.parse, urllib.request
token, chat, text = sys.argv[1], sys.argv[2], sys.argv[3]
body = urllib.parse.urlencode({"chat_id": chat, "text": text}).encode()
urllib.request.urlopen(
    urllib.request.Request(
        f"https://api.telegram.org/bot{token}/sendMessage",
        data=body,
        method="POST",
    ),
    timeout=8,
).read()
PY
mkdir -p "$(dirname "$STAMP")"
date +%s >"$STAMP"
chmod 600 "$STAMP"
echo "monthly-audit-reminder: sent"
