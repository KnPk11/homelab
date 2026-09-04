#!/usr/bin/env bash
# Forward auth,authpriv to the syslog LXC. Run on each trusted Linux SSH host.
set -euo pipefail
SCRIPT_DIR="$(dirname "$(readlink -f "$0")")"
REPO_DIR="/opt/homelab-repo/shared/observability/auth-ship"
if [[ ! -d "$REPO_DIR" ]]; then
  REPO_DIR="$SCRIPT_DIR"
fi

if ! dpkg -s rsyslog >/dev/null 2>&1; then
  DEBIAN_FRONTEND=noninteractive apt-get install -y -qq rsyslog
fi
install -d /etc/systemd/journald.conf.d
cat >/etc/systemd/journald.conf.d/forward-syslog.conf <<'EOF'
[Journal]
ForwardToSyslog=yes
EOF
systemctl restart systemd-journald.service || true
# journald owns /dev/log on some hosts (docker-services); pull AUTH from the journal.
if [[ ! -S /run/systemd/journal/syslog ]]; then
  cat >/etc/rsyslog.d/98-imjournal.conf <<'EOF'
module(load="imjournal" StateFile="imjournal.state")
EOF
fi
host="$(hostname -s 2>/dev/null || true)"
if [[ "$host" == "syslog" ]]; then
  echo "syslog is the collector — skip omfwd (would loop). Use auth-store deploy.sh."
  exit 0
fi
install -m 644 "$REPO_DIR/99-auth-offbox.conf" /etc/rsyslog.d/99-auth-offbox.conf
install -m 644 "$REPO_DIR/auth-ship-heartbeat.service" /etc/systemd/system/auth-ship-heartbeat.service
install -m 644 "$REPO_DIR/auth-ship-heartbeat.timer" /etc/systemd/system/auth-ship-heartbeat.timer
systemctl restart rsyslog
systemctl daemon-reload
systemctl enable --now auth-ship-heartbeat.timer
systemctl is-active rsyslog
echo "auth-ship on ${host} → 192.168.50.89:514"
