#!/usr/bin/env bash
# Send a Homelab Watch Telegram message. Env: BOT_TOKEN/CHAT_ID or TELEGRAM_*.
set -euo pipefail
ENV_FILE="${TELEGRAM_ENV:-/srv/homelab-watch/telegram.env}"
# shellcheck source=/dev/null
set -a
. "$ENV_FILE"
set +a
BOT_TOKEN="${BOT_TOKEN:-${TELEGRAM_BOT_TOKEN:-}}"
CHAT_ID="${CHAT_ID:-${TELEGRAM_CHAT_ID:-}}"
if [[ -z "$BOT_TOKEN" || -z "$CHAT_ID" ]]; then
  echo "telegram-send: missing bot token or chat id in $ENV_FILE" >&2
  exit 1
fi
text="${1:?usage: telegram-send.sh <message>}"
curl -sS --max-time 15 -X POST "https://api.telegram.org/bot${BOT_TOKEN}/sendMessage" \
  --data-urlencode "chat_id=${CHAT_ID}" \
  --data-urlencode "text=${text}" \
  >/dev/null
