#!/usr/bin/env bash
# Install WAN saturation timer on ai-tools (mikrotik-backup key required).
set -euo pipefail
SCRIPT_DIR=$(dirname "$(readlink -f "$0")")

if [[ ! -f /root/.ssh/id_ed25519_mt_backup ]]; then
  echo "deploy.sh: missing ~/.ssh/id_ed25519_mt_backup (svc_backup)" >&2
  exit 1
fi

install -d -m 700 /var/lib/wan-saturation
install -m 755 "$SCRIPT_DIR/wan-saturation.sh" /usr/local/sbin/wan-saturation
install -m 644 "$SCRIPT_DIR/wan-saturation.service" /etc/systemd/system/wan-saturation.service
install -m 644 "$SCRIPT_DIR/wan-saturation.timer" /etc/systemd/system/wan-saturation.timer

install -d -m 700 /srv/homelab-watch || true
if [[ ! -s /etc/ssh/telegram.env && -s /srv/homelab-watch/telegram.env ]]; then
  install -m 600 /srv/homelab-watch/telegram.env /etc/ssh/telegram.env || true
fi
TG=/etc/ssh/telegram.env
[[ -s "$TG" ]] || TG=/srv/homelab-watch/telegram.env

cat > /etc/default/wan-saturation <<EOF
TELEGRAM_ENV=${TG}
SSH_CFG=/opt/dev/homelab_repo/shared/ssh/config
WAN_IFACE=pppoe-out1
RX_MBPS=900
TX_MBPS=110
FIRE_PCT=85
CLEAR_PCT=70
SAMPLES=2
STATE=/var/lib/wan-saturation/state
EOF
chmod 644 /etc/default/wan-saturation

systemctl daemon-reload
systemctl enable --now wan-saturation.timer
echo "wan-saturation installed. next: $(systemctl show wan-saturation.timer -p NextElapseUSec --value 2>/dev/null || true)"
echo "Preview: wan-saturation --dry-run"
