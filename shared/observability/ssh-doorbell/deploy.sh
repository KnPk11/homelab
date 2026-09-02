#!/usr/bin/env bash
# =============================================================================
# deploy.sh — SSH doorbell (shared; nodes/*/services/ssh-doorbell/deploy.sh
# is a relative symlink here)
# Version: 1.1
# Date: 2026-09-01
# =============================================================================
set -euo pipefail
SCRIPT_DIR="$(dirname "$(readlink -f "$0")")"
NOTIFY="$SCRIPT_DIR/ssh-telegram-notify"
PAM_FILE="/etc/pam.d/sshd"
MARKER="ssh-telegram-notify"
# Keep a stable PAM path; point it at the GitOps clone so there is one script.
TARGET_BIN="/usr/local/sbin/ssh-telegram-notify"
REPO_BIN="/opt/homelab-repo/shared/observability/ssh-doorbell/ssh-telegram-notify"
LINE="session optional pam_exec.so quiet ${TARGET_BIN}"

if [[ ! -f "$PAM_FILE" ]]; then
  echo "Error: $PAM_FILE missing" >&2
  exit 1
fi
if [[ ! -x "$NOTIFY" ]]; then
  echo "Error: $NOTIFY missing or not executable" >&2
  exit 1
fi

install -d -m 700 /srv/homelab-watch
if [[ -f /srv/homelab-watch/telegram.env ]]; then
  install -m 600 /srv/homelab-watch/telegram.env /etc/ssh/telegram.env
elif [[ -f /srv/crowdsec/crowdsec.env && ! -r /etc/ssh/telegram.env ]]; then
  python3 - <<'PY'
from pathlib import Path
env = {}
for line in Path("/srv/crowdsec/crowdsec.env").read_text().splitlines():
    if not line.strip() or line.lstrip().startswith("#") or "=" not in line:
        continue
    k, v = line.split("=", 1)
    env[k.strip()] = v
token = env.get("TELEGRAM_BOT_TOKEN") or env.get("BOT_TOKEN")
chat = env.get("TELEGRAM_CHAT_ID") or env.get("CHAT_ID")
if not token or not chat:
    raise SystemExit("no telegram keys in crowdsec.env")
Path("/etc/ssh/telegram.env").write_text(f"BOT_TOKEN={token}\nCHAT_ID={chat}\n")
Path("/etc/ssh/telegram.env").chmod(0o600)
print("Wrote /etc/ssh/telegram.env from crowdsec.env")
PY
fi
if [[ ! -r /etc/ssh/telegram.env ]]; then
  echo "Error: /etc/ssh/telegram.env missing (mode 600, BOT_TOKEN + CHAT_ID)" >&2
  exit 1
fi
chmod 600 /etc/ssh/telegram.env

if [[ -e "$REPO_BIN" ]]; then
  ln -sfn "$REPO_BIN" "$TARGET_BIN"
else
  ln -sfn "$NOTIFY" "$TARGET_BIN"
fi

if grep -qF "$MARKER" "$PAM_FILE"; then
  echo "PAM line already present in $PAM_FILE"
else
  cp -a "$PAM_FILE" "${PAM_FILE}.bak-homelab-watch"
  printf '\n# Homelab Watch SSH doorbell (optional: Telegram down must not block login)\n%s\n' "$LINE" >> "$PAM_FILE"
  echo "Appended PAM line to $PAM_FILE (backup ${PAM_FILE}.bak-homelab-watch)"
fi
echo "SSH doorbell installed (PAM → $TARGET_BIN → $(readlink -f "$TARGET_BIN"))."
