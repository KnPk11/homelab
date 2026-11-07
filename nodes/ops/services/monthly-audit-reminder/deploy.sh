#!/usr/bin/env bash
# Install monthly-audit-reminder timer on ops (CT 112).
set -euo pipefail
SCRIPT_DIR=$(dirname "$(readlink -f "$0")")

install -m 755 "$SCRIPT_DIR/reminder.sh" /usr/local/sbin/monthly-audit-reminder
install -m 644 "$SCRIPT_DIR/reminder.service" /etc/systemd/system/monthly-audit-reminder.service
install -m 644 "$SCRIPT_DIR/reminder.timer" /etc/systemd/system/monthly-audit-reminder.timer
install -d -m 700 /var/lib/monthly-audit

TG=/srv/homelab-watch/telegram.env
cat > /etc/default/monthly-audit <<EOF
TELEGRAM_ENV=${TG}
EOF
chmod 644 /etc/default/monthly-audit

systemctl daemon-reload
systemctl enable --now monthly-audit-reminder.timer
echo "monthly-audit-reminder installed on ops."
echo "Next trigger: $(systemctl show monthly-audit-reminder.timer -p NextElapseUSec --value 2>/dev/null || true)"
