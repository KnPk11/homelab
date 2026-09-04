#!/usr/bin/env bash
# Plaintext auth archive on /mnt/logs/auth. Stops Loki/Promtail on this CT.
set -euo pipefail
REPO="${REPO:-/opt/homelab-repo}"
SRC="$REPO/nodes/syslog/services/auth-store"

if [[ ! -d /mnt/logs ]]; then
  echo "Error: /mnt/logs missing (attach mp0 local-lvm:4,mp=/mnt/logs)" >&2
  exit 1
fi

install -d -m 755 /mnt/logs/auth
chown root:root /mnt/logs /mnt/logs/auth

if [[ ! -d "$SRC" ]]; then
  SRC="$(dirname "$(readlink -f "$0")")"
fi

export DEBIAN_FRONTEND=noninteractive
if ! dpkg -s rsyslog >/dev/null 2>&1; then
  apt-get update -qq
  apt-get install -y -qq rsyslog
fi

install -m 644 "$SRC/rsyslog-receiver.conf" /etc/rsyslog.d/10-auth-receive.conf
# Collector must not omfwd to itself (loop).
rm -f /etc/rsyslog.d/99-auth-offbox.conf
install -m 644 "$SRC/logrotate-auth" /etc/logrotate.d/auth-offbox
install -m 755 "$SRC/auth-watch.sh" /usr/local/sbin/auth-watch
install -m 755 "$SRC/auth-logs" /usr/local/bin/auth-logs
install -m 644 "$SRC/auth-watch.service" /etc/systemd/system/auth-watch.service
install -m 644 "$SRC/auth-watch.timer" /etc/systemd/system/auth-watch.timer

systemctl disable --now loki.service promtail.service 2>/dev/null || true
rm -f /etc/systemd/system/promtail.service.d/bind514.conf
rmdir /etc/systemd/system/promtail.service.d 2>/dev/null || true

if [[ -d /mnt/logs/loki || -d /mnt/logs/promtail ]]; then
  install -d -m 700 /mnt/logs/.loki-old
  [[ -d /mnt/logs/loki ]] && mv /mnt/logs/loki /mnt/logs/.loki-old/loki
  [[ -d /mnt/logs/promtail ]] && mv /mnt/logs/promtail /mnt/logs/.loki-old/promtail
fi

install -d -m 700 /srv/homelab-watch
if [[ ! -s /srv/homelab-watch/telegram.env && -r /etc/ssh/telegram.env ]]; then
  install -m 600 /etc/ssh/telegram.env /srv/homelab-watch/telegram.env
fi

systemctl daemon-reload
systemctl restart rsyslog.service
systemctl enable --now rsyslog.service auth-watch.timer
systemctl is-active rsyslog.service
ss -lntp | grep -E ':514\s' || echo "WARN: nothing listening on :514" >&2
echo "plaintext auth → /mnt/logs/auth/<host>/auth.log"
echo "auth-logs  |  SMB \\\\$(hostname -s)\\logs\\auth"
