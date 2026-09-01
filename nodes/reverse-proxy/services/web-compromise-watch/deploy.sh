#!/usr/bin/env bash
# =============================================================================
# deploy.sh — web-compromise-watch (reverse-proxy)
# Version: 1.0
# Date: 2026-09-01
# =============================================================================
set -euo pipefail
SCRIPT_DIR="$(dirname "$(readlink -f "$0")")"
SHARED="${SCRIPT_DIR}/../../../../shared/observability/web-compromise-watch"
if [[ ! -d "$SHARED" ]]; then
  SHARED="/opt/homelab-repo/shared/observability/web-compromise-watch"
fi

install -d -m 755 /srv/web-compromise-watch /srv/homelab-watch
if [[ ! -f /srv/web-compromise-watch/exec-watch.env ]]; then
  cp "$SCRIPT_DIR/exec-watch.env.example" /srv/web-compromise-watch/exec-watch.env
  chmod 600 /srv/web-compromise-watch/exec-watch.env
fi
if [[ ! -f /srv/homelab-watch/telegram.env ]]; then
  echo "Error: /srv/homelab-watch/telegram.env missing (BOT_TOKEN + CHAT_ID)."
  exit 1
fi
chmod 600 /srv/homelab-watch/telegram.env

install -m 755 "$SHARED/telegram-send.sh" /usr/local/sbin/homelab-watch-send
install -m 755 "$SHARED/exec-watch.sh" /usr/local/sbin/web-compromise-exec-watch
install -m 644 "$SHARED/exec-watch.service" /etc/systemd/system/web-compromise-exec-watch.service

systemctl daemon-reload
systemctl enable --now web-compromise-exec-watch.service
systemctl is-active web-compromise-exec-watch.service
echo "Deployment complete."
