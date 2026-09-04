#!/usr/bin/env bash
# Plaintext auth files → Homelab Watch. useradd/usermod, or a host with no lines for 15m.
set -euo pipefail
ENV_FILE="${TELEGRAM_ENV:-/srv/homelab-watch/telegram.env}"
LOGROOT="${AUTH_LOGROOT:-/mnt/logs/auth}"
# shellcheck source=/dev/null
set -a
[[ -r "$ENV_FILE" ]] && . "$ENV_FILE"
set +a
BOT_TOKEN="${BOT_TOKEN:-${TELEGRAM_BOT_TOKEN:-}}"
CHAT_ID="${CHAT_ID:-${TELEGRAM_CHAT_ID:-}}"
[[ -n "$BOT_TOKEN" && -n "$CHAT_ID" ]] || exit 0

send() {
  python3 - "$BOT_TOKEN" "$CHAT_ID" "📜 $1" <<'PY' || true
import sys, urllib.parse, urllib.request
token, chat, text = sys.argv[1], sys.argv[2], sys.argv[3]
body = urllib.parse.urlencode({"chat_id": chat, "text": text}).encode()
urllib.request.urlopen(
    urllib.request.Request(f"https://api.telegram.org/bot{token}/sendMessage", data=body, method="POST"),
    timeout=8,
).read()
PY
}

cutoff_epoch="$(($(date +%s) - 900))"
if grep -Eiq 'useradd|usermod' "$LOGROOT"/*/auth.log 2>/dev/null; then
  if python3 - "$LOGROOT" "$cutoff_epoch" <<'PY'
import pathlib, re, sys, time
from datetime import datetime, timezone
root, cutoff = pathlib.Path(sys.argv[1]), int(sys.argv[2])
pat = re.compile(r"useradd|usermod", re.I)
tsre = re.compile(r"^(\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2})")
now = time.time()
for path in root.glob("*/auth.log"):
    try:
        text = path.read_text(encoding="utf-8", errors="replace")
    except OSError:
        continue
    for line in text.splitlines():
        if not pat.search(line):
            continue
        m = tsre.match(line)
        if not m:
            continue
        ts = datetime.strptime(m.group(1), "%Y-%m-%d %H:%M:%S").replace(tzinfo=timezone.utc).timestamp()
        if ts >= cutoff:
            sys.exit(0)
sys.exit(1)
PY
  then
    send "auth: useradd/usermod in the last 15m"
  fi
fi

HOSTS="${AUTH_WATCH_HOSTS:-proxmox-host,docker-services,nas,lab-vm,reverse-proxy,ai-tools,dns,pulse,vpns,pbs,k8s,scratch-pc}"
IFS=',' read -r -a arr <<< "$HOSTS"
for h in "${arr[@]}"; do
  h="${h// /}"
  [[ -n "$h" ]] || continue
  f="$LOGROOT/$h/auth.log"
  if [[ ! -f "$f" ]]; then
    send "auth: no file for ${h} (shipper?)"
    continue
  fi
  mtime="$(stat -c %Y "$f" 2>/dev/null || echo 0)"
  if [[ "$mtime" -lt "$cutoff_epoch" ]]; then
    send "auth: no lines from ${h} for 15m (shipper?)"
  fi
done
