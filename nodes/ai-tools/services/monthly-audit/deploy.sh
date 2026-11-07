#!/usr/bin/env bash
# Install monthly-audit on ai-tools only. Reminder timer lives on ops (CT 112).
set -euo pipefail
SCRIPT_DIR=$(dirname "$(readlink -f "$0")")

install -d -m 755 /usr/local/share/monthly-audit
install -m 755 "$SCRIPT_DIR/monthly-audit.sh" /usr/local/sbin/monthly-audit
install -m 644 "$SCRIPT_DIR/digest.schema.json" /usr/local/share/monthly-audit/digest.schema.json
install -d -m 700 /var/lib/monthly-audit

TG=/etc/ssh/telegram.env
[[ -s "$TG" ]] || TG=/srv/homelab-watch/telegram.env
cat > /etc/default/monthly-audit <<EOF
TELEGRAM_ENV=${TG}
REPO=/opt/dev/homelab_repo
# AUDIT_MODEL=gemini-3.8-flash-high
EOF
chmod 644 /etc/default/monthly-audit

echo "monthly-audit installed on ai-tools."
echo "Run: monthly-audit --light --llm agy   or   --llm grok"
